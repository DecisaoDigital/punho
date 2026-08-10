# Reconciliação repo ↔ produção — 10 de Agosto de 2026

Estado antes: 58 ficheiros em `supabase/migrations/` para 96 versões aplicadas
em `oefqbkhioncakojipqyx`. Duas contagens que nunca podiam bater porque nem
sequer falavam a mesma língua — o repositório numerava por dia
(`20260725_punho_core.sql`) e o registo numera ao segundo
(`20260726024802`).

## O que se fez

**Não se fez `supabase db pull`.** O `db pull` gera **um** ficheiro com o
retrato do esquema inteiro, e isso não é reconciliar: é escrever por cima de 58
migrations comentadas uma só que não explica nada. Contra a regra que ficou no
`AGENTS.md`. A fonte usada foi outra: `supabase_migrations.schema_migrations`,
onde as 100 versões aplicadas têm o SQL guardado na coluna `statements`.

**56 ficheiros renomeados** para o carimbo com que estão registados na base. O
conteúdo não se tocou — vale a regra: fica a versão escrita à mão. Oito tinham
também o nome trocado (o registo chama `catalogo_aceita_punho_op` ao que o
repositório chamava `punho_op_no_catalogo`, e por aí); ficaram com o nome do
registo, que é o que a CLI compara.

**Três migrations desta sessão** foram aplicadas pelo MCP, que carimba com a
hora de aplicação e não com o nome do ficheiro. Renomeadas para o carimbo real
(`20260810065258`, `20260810065734`, `20260810070743`).

**Duas migrations vivas mas nunca registadas:** `punho_contabilista` e
`punho_contabilista_periodo_efectivo`. As nove funções `punho_*_contabilista`
existem em produção, portanto o SQL correu — mas correu solto, sem passar pelo
registo. É exactamente a deriva que a regra nova trava, apanhada em flagrante.
Registadas como aplicadas (`20260804133600` e `…601`) para os dois lados
passarem a concordar.

> **Ressalva, e é importante:** registei-as como aplicadas porque as funções
> existem, não porque tenha comparado linha a linha o ficheiro com o que está
> vivo. Se alguém andou a mexer nessas funções por SQL solto depois de o
> ficheiro ser escrito, o ficheiro está desactualizado e o registo agora diz que
> não está. Desfaz-se com um `delete` das duas versões.

## O que fica por fazer, e porquê

**49 versões estão em produção sem ficheiro nenhum no repositório.** Estão todas
com o SQL guardado em `schema_migrations.statements` — recuperam-se, não se
perderam. O que falta é a **palavra-passe da base**: sem ela nem a CLI
(`supabase db pull`, `migration list --linked`) nem o `psql` falam com o
servidor, e a alternativa — puxar 49 migrations pela API para dentro do contexto
de um agente — custa mais em tokens do que vale.

Com a palavra-passe isto resolve-se de uma assentada:

```bash
psql "$DB_URL" -At -F$'\t' -c \
  "select version, name, array_to_string(statements, E';\n') from supabase_migrations.schema_migrations order by version" \
| while IFS=$'\t' read -r v n s; do
    [ -f "supabase/migrations/${v}_${n}.sql" ] || printf '%s\n' "$s" > "supabase/migrations/${v}_${n}.sql"
  done
```

Repare-se no `[ -f ... ] ||`: só escreve o que falta. Nunca passa por cima de
uma migration escrita à mão.

## Como verificar daqui para a frente

```bash
supabase migration list --linked          # pede a palavra-passe
```

Todas as linhas têm de ter carimbo dos dois lados. Uma linha só com `Remote` é
uma alteração feita em produção sem migration no repositório — e isso agora tem
uma regra própria no `AGENTS.md`.
