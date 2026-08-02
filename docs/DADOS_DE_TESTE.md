# Dados de teste — Lavandaria Mare Alta

Ficheiro: `supabase/seeds/mare_alta.sql`

## O que faz

Popula a empresa de teste **Lavandaria Mare Alta** (`empresa_id = 1a267759-faeb-473e-828d-cea53cd8bbb3`,
conta `cesarmendes78+punhoteste@gmail.com`) com dados simulados coerentes, escrevendo
directamente na tabela `punho_operacoes` — **não** nas tabelas "materializadas"
(`punho_clientes`, `punho_maquinas`, etc.), porque essas estão a 0 linhas na produção
apesar de a app já ter criado dados reais para esta empresa. A fonte de verdade
confirmada por inspecção directa da base de dados é o log append-only
`punho_operacoes`: cada operação é uma linha `(entidade, entidade_id, payload)`, e o
telemóvel sincroniza por `seq` (há um trigger `punho_operacoes_avisar` que notifica
em tempo real via Supabase Realtime).

### Registos criados

| Entidade | Quantos | Notas |
|---|---|---|
| `collaborator` | 2 | Sofia Nunes (encarregada de engomadoria, activa); Rui Pinto (ex-colaborador, **arquivado**, nunca responsável por reserva) |
| `vehicle` | 1 | Furgoneta mais antiga (2016), matrícula formato pré-2020 (`00-AA-00`) |
| `customer` | 4 | 2 particulares (NIF pessoal) + 2 empresas (NIF válido), moradas/códigos-postais reais da zona da Nazaré |
| `booking` | 6 | 2 concluídas (passado), 2 confirmadas (futuro), 1 pedido por confirmar, **1 cancelada** |
| `expense` | 26 | Renda + electricidade em 11 meses (ago/2025–jun/2026), com combustível, manutenção, consumíveis e publicidade pontuais |
| `receipt` | 15 | 1–2 por mês, valor e método variando com a sazonalidade (época alta Jun–Set) |

Os NIF novos têm dígito de controlo validado pelo algoritmo oficial português. Os NISS
(Segurança Social) são apenas 11 dígitos no formato visto nos dados reais — não há
checksum público fiável para os validar.

**Não populado de propósito:** um "histórico mensal" agregado à parte
(`punho_estado_operacional.historicalMonths`). Essa tabela é um mecanismo alternativo
de sync (monolítico, só por RPC `punho_guardar_estado_operacional`) que está a 0 linhas
em produção — não há confirmação de que escrever lá directamente chegue ao telemóvel.
Em vez disso, os 26 despesas + 15 recebimentos espalhados por 11 meses já dão histórico
real com sazonalidade a qualquer ecrã que agregue por data.

**Não tocado:** os registos manuais dos testes já existentes (`Cliente Sino`, `Teste
Duplicados`, `Campainha Teste`, `Ana Ferreira`, os "Duplicado ..." de teste de
duplicados) e as máquinas já corrigidas por seeds anteriores (`seed-precos`,
`seed-servidor`). O seed não os apaga nem os sobrepõe.

## Como aplicar

1. Abrir o SQL Editor do projecto Supabase `oefqbkhioncakojipqyx` (ou usar a CLI local
   apontada a esse projecto).
2. Colar o conteúdo de `supabase/seeds/mare_alta.sql` e correr.
3. É idempotente: pode correr-se várias vezes sem duplicar (o próprio bloco apaga
   primeiro tudo o que tenha marcado com `por_dispositivo = 'seed-mare-alta'` para
   esta empresa, antes de reinserir).
4. No telemóvel de teste, fazer pull/refresh (ou esperar pela notificação em tempo
   real) para os dados chegarem via a sincronização normal.

## Como limpar

No fim do ficheiro há um bloco comentado:

```sql
delete from public.punho_operacoes
 where empresa_id = '1a267759-faeb-473e-828d-cea53cd8bbb3'
   and por_dispositivo = 'seed-mare-alta';
```

Descomentar e correr para remover tudo o que este seed inseriu, sem tocar nos
registos manuais dos testes.

## Como apontar a outra empresa

Editar apenas duas linhas no `declare` do bloco `do $$ ... $$`, no topo do ficheiro:

```sql
v_empresa    uuid := '<empresa_id da outra empresa>';
v_utilizador uuid := '<user_id de um gestor activo dessa empresa>';
```

(confirmar o `user_id` com `select id, user_id from punho_membros where empresa_id = '...' and ativo`).
Se for reaproveitar o ficheiro para duas empresas de teste em simultâneo, mudar também
os prefixos dos UUID literais (`11111111-`, `22222222-`, etc.) para não confundir
visualmente os registos ao inspeccionar a tabela.

## O que não foi verificado

- O ficheiro nunca foi corrido (o agente que o escreveu só tinha acesso de leitura à
  base de dados). Nomes de tabela/coluna, check constraints e enums foram confirmados
  contra `information_schema` e contra `lib/domain/models/operations.dart`,
  `workforce.dart` e `finance.dart` — mas a validação real só acontece quando for
  aplicado.
- O comportamento exacto do pull no telemóvel (frequência, se precisa de pull-to-
  refresh manual) não foi observado ao vivo.
