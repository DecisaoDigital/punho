# Handover — C3, as funções deixam de nascer abertas

**Data:** 10 de Agosto de 2026
**Branch:** `fase3/um-so-sync`
**Estado:** fechado. Aplicado em produção e provado.

Terceira vez em três dias que uma função nasceu executável por quem não devia
(projecção a 8/8, `punho_colaborador_pode_escrever` a 9/8,
`punho_migrar_entidades_do_instantaneo` a 10/8). Correr os advisors a seguir a
cada migration trata o sintoma. Isto trata a causa.

**Antes:** 20 funções não-gatilho executáveis por `anon`, 14 delas `security
definer`. **Depois:** 5, todas de identidade, todas com razão escrita.
**Abertas a PUBLIC: zero, em 82.**

---

## O que fez

### Três migrations, aplicadas por esta ordem

| Ficheiro | O quê |
|---|---|
| `20260810160000_punho_funcoes_nascem_fechadas.sql` | `revoke execute on all functions in schema public from public, anon, authenticated`, seguido de 35 grants explícitos — a lista aprovada. Mais o `alter default privileges`. Mais o `comment on function punho_id_estavel` com a armadilha das vistas. |
| `20260810161000_punho_gatilho_de_evento_fecha_o_public.sql` | O gatilho de evento `punho_funcao_nova_nasce_fechada`, porque o `alter default privileges` **não fecha o PUBLIC** — ver «o que descobriu». |
| `20260810162000_punho_search_path_do_gatilho_de_evento.sql` | `set search_path` na função do gatilho. WARN novo que os advisors apanharam, e era meu. |

Todas reversíveis, com o como-desfazer no topo do próprio ficheiro.

### Um teste que impede a recaída

`supabase/tests/rls_funcoes_fechadas.sql`, seis blocos:

| Bloco | Falha se |
|---|---|
| 0 | houver sobrecargas (as listas são por nome; com sobrecargas deixavam de ser sólidas) |
| A | **qualquer** função de `public` for executável por PUBLIC — sem lista de excepções |
| B | a lista do `anon` não for exactamente as cinco — a mais **ou** a menos |
| C | a lista do `authenticated` não for exactamente as trinta e cinco |
| D | uma função criada de propósito nascer aberta |
| E | o gatilho de evento tiver desaparecido ou estar desactivado |

A lista aprovada vive no ficheiro, com a razão de cada entrada e o cliente que
a chama escrito ao lado. E o cabeçalho leva a consulta que procura uma função
nos quatro sítios onde ela pode estar escondida — políticas, vistas, corpos de
outras funções, constraints — para ninguém ter de descobrir a armadilha
seguinte por acidente.

### A prova

| O quê | Resultado |
|---|---|
| `rls_smoke_isolamento_empresas.sql`, blocos 1 e 2 | **PASSOU** os dois. Base limpa a seguir. |
| `rls_funcoes_fechadas.sql`, blocos 0–E | **PASSOU** os seis |
| Contraprova: abrir uma porta de propósito | o bloco B **apanhou-a**. Um teste que nunca falha não é um teste. |
| Função nova nasce fechada | `postgres=X \| service_role=X`. anon `false`, authenticated `false`. |
| Advisors | 57 → **44** lints. `anon_security_definer`: 14 → **5**. |

### Fluxos com sessão real, por HTTP, sobre o PostgREST

Não em SQL: com JWT verdadeiro, pela mesma porta que a app usa.

| Papel | O quê | Resultado |
|---|---|---|
| anon | `punho_validar_convite` (o único pré-login) | 200 `"invalido"` |
| anon | `punho_meu_acesso`, `punho_reservas_em_dia`, `punho_pedidos_da_minha_empresa`, `punho_lacunas_contabilista` | **401 / 42501** |
| gestor | entrar, `punho_meu_acesso`, `punho_e_gestor`, pedidos, lacunas | 200 |
| gestor | ler o painel — as sete vistas `security_invoker` | 200, com linhas |
| gestor | criar cliente (pelo log) e lê-lo de volta pela vista | 201 → visível |
| gestor | `punho_painel_gravar` — o canal novo da Fase 3, por HTTP | 200 |
| operador | entrar, `punho_reservas_em_dia`, ler máquinas e reservas | 200 |
| operador | criar reserva → **entregar a máquina** (`confirmed` → `rented`) | 201, e o gestor vê `rented` |
| operador | **cobrar** (recibo) | 201 |
| operador | criar máquina | **403** «Criar máquinas é do gestor.» |
| operador | criar ficha de pessoal | **403** «Criar fichas de pessoal é do gestor.» |
| gestor | `punho_projeccao_atraso`, `punho_nif_valido`, `punho_serie_mensal_contabilista`, `punho_reprojectar_empresa`, `punho_migrar_entidades_do_instantaneo` | **403 / 42501** — fechadas, como se queria |

Os dois 403 do operador são **regras de negócio**, não privilégios: as
mensagens vêm do gatilho de campos do colaborador, que continua intacto.

Sondas todas apagadas: `c3-sonda-*` a zero em operações, reservas, clientes,
recebimentos e painel.

---

## O que ficou por fazer

### 1. As políticas com `roles = {public}` — pendente, e é tarefa própria

**É a causa das cinco funções que ficam abertas a `anon`.**
`punho_empresa_atual`, `punho_e_gestor`, `punho_membro_ativo` e
`punho_perfil_na_empresa` estão em políticas cujo papel é `{public}`. Enquanto
a política servir PUBLIC, `anon` tem de poder executar o que ela chama, ou
qualquer consulta anónima passa a dar `42501` em vez de devolver vazio.

Passá-las a `to authenticated` fecha as quatro de uma vez. As tabelas afectadas:
`punho_reservas`, `punho_campanhas`, `punho_documentos`, `punho_instalacoes`,
`punho_reserva_maquinas` e as `*_copia_2026_08_09`.

**Mexe em políticas** — o que esta tarefa tinha proibido — e exige o
`rls_smoke_isolamento_empresas.sql` a correr por cima. Não é um remendo a meio
de outra coisa.

A quinta, `punho_validar_convite`, não sai: é chamada antes do `signUp`.

### 2. Quatro WARN de `search_path` que não são meus

`limitar_pings_por_maquina`, `versoes_apps_check_release_integrity`,
`gerar_chave_mestre`, `notificar_novo_terminal` — todas do lado do
WashInvoice/Control. Ficam assinaladas, fora do âmbito.

### 3. `punho_meu_estado_acesso` sai quando não houver instalações antigas

Substituída por `punho_meu_acesso` a 5 de Agosto e desde então não é chamada
por nenhum dos três repositórios. Ficou aberta a `authenticated` só por causa
de APKs já instalados. Tirar da lista do bloco C quando não houver nenhum.

### 4. Contas de ensaio

`scratchpad/contas_teste.env` desapareceu com o scratchpad da sessão de 9 Ago.
Repus a palavra-passe das duas contas da **Lavandaria Nocturna (teste)** —
`gestor.nocturno@` e `operador.nocturno@decisaodigital.pt` — para
`EnsaioC3-2026`, por SQL. Contas de teste, empresa de teste. Se quiseres outra,
é um `update auth.users set encrypted_password = crypt('...', gen_salt('bf'))`.

---

## O que descobriu pelo caminho

### 1. `alter default privileges ... revoke ... from public` é aceite e **não faz nada**

Era o passo 2.3 do teu prompt, e teria dado exactamente a ilusão de estar
resolvido. Corri-o, criei uma função a seguir, e ela nasceu com `=X/postgres` —
PUBLIC de pé, `anon` a poder executar por ser membro de PUBLIC.

Ao criar um objecto, o Postgres faz (`aclchk.c`, `get_user_default_acl`):

```c
result = acldefault(objtype, ownerId);       // os valores de fábrica
result = aclmerge(result, defacl, ownerId);  // o que está em pg_default_acl
```

e `aclmerge` chama `aclupdate` com `ACL_MODECHG_ADD`. **Só soma.** O que está em
`pg_default_acl` acrescenta privilégios aos de fábrica; nunca lhos tira. E
EXECUTE a PUBLIC nas funções é de fábrica.

O que fecha isto é um **gatilho de evento** em `ddl_command_end`. O papel
`postgres` da Supabase não é superuser mas pode criá-los — confirmado.

Só se apanha criando uma função e olhando para o ACL. Foi o passo 3(d).

### 2. Havia **duas** fontes de EXECUTE por omissão, não uma

1. o Postgres dá a PUBLIC (`=X/postgres` — um `=X` sem papel à esquerda);
2. a Supabase tem um `pg_default_acl` próprio, para o papel `postgres` e o
   schema `public`, que dá EXECUTE a `anon`, `authenticated` e `service_role`
   em cada função criada.

Daí `revoke ... from public, anon, authenticated`. Só de PUBLIC não chegava, e
só dos dois papéis também não — que foi o erro de 10 de Agosto de manhã.

O `pg_default_acl` de `postgres` ficou em `postgres=X | service_role=X`.
Há uma segunda linha para `supabase_admin`, que só vale para objectos criados
por eles e a que `postgres` não tem acesso (não é membro do papel).

### 3. A segunda armadilha não estava em `pg_policies`

`punho_id_estavel` não aparece em política nenhuma, mas está no corpo das
**sete vistas `security_invoker`** do painel: `punho_maquinas`,
`punho_clientes`, `punho_leads`, `punho_despesas`, `punho_recebimentos`,
`punho_veiculos`, `punho_colaboradores`. Uma vista invoker avalia-se com os
privilégios de quem consulta. Fechá-la a `authenticated` matava as sete listas.

Ficou escrito num `comment on function`, onde quem for revogar olha, e não só
neste ficheiro.

Primeiro foram as políticas, agora as vistas. A terceira será noutro sítio —
por isso é que o cabeçalho do teste tem a consulta que procura nos quatro.

### 4. Há **três** clientes, não dois

`~/punho_operador` — o Punho OP — chama `punho_guardar_o_meu_perfil`,
`punho_reservas_em_dia` e `punho_meu_acesso`. Faltou-me na primeira leitura e
teria fechado duas funções que ele usa todos os dias.

E o regex enganou: `punho_reservas_em_dia` é chamada como `.rpc<dynamic>(`, com
o parâmetro de tipo entre `rpc` e o parêntesis. Um `grep "rpc("` não a apanha.
O varrimento definitivo foi cruzar os **56 nomes** contra os três repositórios,
não procurar chamadas.

### 5. `punho_validar_convite` é a única RPC pré-login

`registo_screen.dart:102`, antes do `signUp`: valida o código para dar a razão
concreta em vez do erro genérico do gatilho. Fechá-la a `anon` partia o registo
com convite — sem erro visível no código, só na app de quem se está a registar.

### 6. Os 30 WARN que restam são a fronteira, não dívida

`authenticated_security_definer_function_executable` continua a assinalar 30
funções. São exactamente a lista aprovada: `security definer` com o gate de
negócio **dentro** (`is_admin()`, `punho_e_gestor()`, `auth.uid()`). O advisor
não sabe ler o gate; vê a porta. Fechá-las era fechar as três apps.

O que mudou de verdade mede-se noutro sítio: `anon_security_definer` de 14
para 5, e **zero** funções abertas a PUBLIC.

---

## Como confirmar, daqui a um mês

```sql
-- os seis blocos, no SQL Editor
\i supabase/tests/rls_funcoes_fechadas.sql

-- o número que interessa
select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and has_function_privilege('public', p.oid, 'execute');
-- tem de dar 0
```
