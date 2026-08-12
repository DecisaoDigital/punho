# RGPD — o que se guarda, durante quanto tempo, e como se apaga

Estado a 11 Ago 2026. Aplica-se ao projecto Supabase `oefqbkhioncakojipqyx`,
que serve o Punho, o Punho OP e o WashInvoice Control.

---

## 1. Onde estão os dados pessoais

A maior parte **não está numa tabela** — está dentro do `payload` de
`punho_operacoes`, que é append-only e é o que re-hidrata os terminais.

| Entidade no log | Campos pessoais |
|---|---|
| `customer` | `name`, `taxId`, `phone`, `email`, `address`, `locality`, `postalCode`, `notes` |
| `collaborator` | `name`, `taxId`, `phone`, `socialSecurityNumber`, `maritalStatus`, `dependents`, `notes` |
| `lead` | `name`, `phone`, `summary` |
| `booking` | `customerNameSnapshot`, `collaboratorNameSnapshot` — o nome é **copiado** para dentro de cada reserva |

Em tabelas, há ainda 48 colunas pessoais espalhadas por ~30 tabelas: NIF e nome
em `licencas`, `chaves_mestre`, `pings`, `aceites_termos`, `sugestoes`,
`pedidos_ajuda`, `pedidos_renovacao`; email e nome em `pedidos_acesso`,
`punho_pedidos_acesso`, `convites_organizacao`, `punho_convites*`; contactos em
`punho_leads_entrada`; segredos em `licencas.at_password_cifrada`,
`credenciais_wse_cliente.password_cifrada`, `admin_dispositivos.fcm_token`.

---

## 2. Prazos de retenção

Corre sozinho todos os dias às **04:17 UTC** (`pg_cron`, job
`punho_expurgo_diario` → `punho_expurgar_dados()`).

| Tabela | Prazo | Porquê |
|---|---|---|
| `pings` | 30 dias | telemetria, sem obrigação legal |
| `punho_erros` | 30 dias | diagnóstico, morre com a versão |
| `registar_terminal_tentativas` | 30 dias | rate limit, não é histórico |
| `punho_leads_entrada` | 6 meses | contacto que nunca converteu |
| `licencas_audit` | 12 meses | prova de decisões sobre licenças |

**Intocado de propósito:** recibos, despesas, séries comunicadas, guias,
assinaturas, licenças activas e tudo o que seja colaborador — manda a lei fiscal
(10 anos, CIVA art. 52.º) e a laboral (5 anos).

Cada passagem deixa registo em `punho_expurgos` (data + contagens). Sem esse
registo, «temos retenção» seria uma afirmação sem prova.

---

## 2.1 Base legal das leads que chegam de fora

`punho_leads_entrada` é o único sítio onde entram dados de gente que **nunca
instalou a app e nunca nos disse nada**. Desde 12 Ago 2026 cada linha diz o que
autoriza guardá-la:

| `base_legal` | Quando | O que fica guardado |
|---|---|---|
| `consentimento` | formulário público | o **texto** que a pessoa aceitou, a versão, o endereço da página, e o carimbo de quando nos chegou |
| `diligencia_pre_contratual` | telefone, WhatsApp, agenda | nada mais — a pessoa procurou o negócio (art. 6.º/1/b) |
| `nao_registada` | tudo o resto | nada, e diz-se |

Duas regras dão a isto valor de prova:

1. **Não se pode fingir.** Uma restrição `check` exige texto e carimbo para
   dizer `consentimento`, e proíbe meia prova pendurada noutra base — porque um
   registo falso passa numa auditoria que um registo em falta não passaria.
2. **Não se pode reescrever.** O `authenticated` tinha a tabela toda
   (`arwdDxtm`), o que deixava um gestor carimbar consentimento numa lead que
   nunca consentiu. Ficou com `select` e `update` de duas colunas —
   `processada_em` e `lead_local_id` — que é tudo o que a app faz. Provado com o
   papel trocado dentro da base: 42501 a reescrever a base legal, a forjar a
   prova e a apagar; passa a marcar como processada e a ler.

E `nao_registada` **não entra sozinha no pipeline**, mesmo classificada de
`aceite`: fica retida à espera de um toque. Entrar no pipeline é copiar a pessoa
para dentro do log append-only, onde apagar deixa de ser apagar e passa a ser
redigir. O contrato do formulário está no cabeçalho de
`supabase/functions/receber-lead/index.ts`.

---

## 3. Como se responde a um pedido de apagamento

O log é append-only: não se apagam linhas, **redige-se** o conteúdo. A linha e o
`seq` ficam, o `name` passa a «Titular apagado», o resto a `null`, e carimba-se
`_apagado_em`. A projecção e a re-hidratação continuam a funcionar.

Com sessão de **gestor** da empresa (a empresa sai da sessão, nunca do pedido):

```sql
-- 1. encontrar TODAS as fichas da pessoa — pode estar duplicada
select * from punho_procurar_titular('Casa Ferreira');

-- 2. apagar cada uma
select punho_apagar_titular('customer', 'cli-prova-998368', 'pedido do titular 11/8');

-- 3. a prova fica aqui
select * from punho_apagamentos order by feito_em desc;
```

O passo 1 não é opcional. Na prova de 11/8, a mesma pessoa tinha **três** fichas
na mesma empresa; apagar uma dava uma resposta que parecia completa e não era.

O que a função varre, por cada ficha: todas as revisões da entidade no log · o
nome copiado para dentro das reservas no log (`customerNameSnapshot`,
`collaboratorNameSnapshot`) · o mesmo nome na tabela projectada
`punho_reservas`. Não toca em dinheiro nem em datas — apaga-se quem, não quanto.

**Recusas** (provadas): colaborador a tentar apagar → `42501` · ficha de outra
empresa → `P0002` · entidade que não é pessoa (`machine`) → `22023` · sem id →
`22023`.

---

## 4. O que falta

- **Não há botão.** As funções existem, a app não as chama. Hoje um pedido de
  apagamento resolve-se por SQL.
- **Sem exportação de dados** (art. 20.º, portabilidade). Só existe o apagamento.
- **`leaked password protection` desligada** no Supabase Auth — muda-se no
  painel, não por migração.
- **`licencas_audit` guarda NIF e nome** dentro de `antes`/`depois`, e 62 das
  113 linhas apontam para licenças já apagadas. O prazo de 12 meses limpa-as com
  o tempo; a origem (falta de FK) fica para a passagem de integridade.
- Nada disto está commitado.
