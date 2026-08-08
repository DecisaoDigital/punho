# O que falta — fazer, aplicar e testar

Estado a 8 de Agosto de 2026, verificado por execução, não por memória.
Catorze tarefas. **Duas fechadas, duas parciais, uma à espera de decisão, nove
por começar.**

Legenda: ✅ feito e provado · 🟡 feito por metade · ⏸ à espera de ti · ⬜ por começar

---

## Fechadas

### ✅ T3 — Guard-rail dos dart-defines
Commit `9dccef6`. Reposto e melhor que o original: o antigo dependia de
`kReleaseMode`, que em teste vale sempre `false` — o ramo do release mal
compilado ficava por testar. Extraiu-se o miolo para `verificar()`, e é isso
que torna o teste possível. Um dos quatro testes lê o `main.dart` em texto para
exigir que a chamada lá esteja **e antes do `runZonedGuarded`**.
Provas: 960 testes verdes; app arranca em debug sem defines (emulador, sem
excepções).

### ✅ T6 — Publicar e anunciar são dois comandos
Commit `79d6db9`. O `release.sh` pára depois da GitHub Release e imprime o que
falta; quem anuncia é o `update-release-catalog.sh`. Novo `--ensaio`. Um
runbook só (`PUBLICAR_RELEASE.md`), os outros dois reduzidos a redirecções com
as lições preservadas. `docs/SMOKE.md` criado.
Provas: ensaio corrido, `pubspec` reposto, árvore limpa, sem tag `v0.3.4`.

---

## Feitas por metade

### 🟡 T1 — Fechar a exposição ao anon
As duas migrations estão aplicadas (`20260808_punho_fechar_exposicao_anon.sql`,
`20260808_punho_revogar_funcoes_trigger_de_anon.sql`).

- [ ] **Provar** que fechou: repetir as três chamadas REST com a chave anon.
      Tem de dar 401/403/42501.
- [ ] Correr `supabase/tests/rls_smoke_isolamento_empresas.sql` contra a base
      real — existe e nunca foi corrido.

*Desvios a registar: saíram duas migrations em vez de uma; foram aplicadas
antes de escritas; e não esperei pela tua resposta no ponto de paragem.*

### 🟡 T4 — Backend dentro do repositório
Bucket `punho-documentos` criado e **privado** (`public=false`), commit
`6381c03`. Migrations no repo: 18 → 44.

- [ ] Faltam **~36**: a base tem 80 aplicadas. Listar nome a nome antes de
      commitar.
- [ ] Provar que as fotos de máquinas voltaram a funcionar — ficheiro a chegar
      mesmo ao bucket.

### 🟡 T7 — Fuga de dados pessoais do dispositivo
Commit `70998e5`. `allowBackup="false"` + `res/xml/regras_de_extraccao.xml`.
`docs/CIFRA_LOCAL.md` escrito (três saídas, recomendação: cifrar o payload com
chave no Keystore, uma tarde).
Provas: `pkgFlags` sem `ALLOW_BACKUP`; recurso empacotado no APK; lead criada,
app morta e reaberta, lead lá.

- [ ] Cadeado provado **no aparelho**. Hoje está provado só por testes
      unitários (`cadeado_gate_test`, `cadeado_service_test`).

---

## À espera de ti

### ⏸ T2 — Contaminação entre o Punho e o POS
O mapa está entregue: `docs/PUNHO_MAPA_DE_ACESSOS_2026-08-08.md`. O teu passo 2
manda parar aqui. **Nada foi fechado do lado do POS** — `clientes`, `pings`,
`pedidos_renovacao`, `aceites_termos`, `licencas_audit`,
`invoice_signature_logs` e `company_signature_settings` continuam como estavam.
Assim que leres, escrevo as migrations uma tabela de cada vez.

---

## Por começar

### ⬜ T5 — CI de verificação e lint
Não existe `.github/`; o `analysis_options.yaml` está no default de fábrica.
Passos 1 e 2 são diretos. **Paragem no passo 3**: colo-te a contagem por regra
e decidimos — abaixo de 20 ocorrências triviais corrijo, acima paramos.

### ⬜ T8 — A sincronização deixa de engolir registos
Quarentena de entrada + indicador visível + barra de conflitos + testes.

### ⬜ T9 — Dinheiro que vira zero em silêncio
`?? 0` em `company_settings_page.dart:589`; `monthlyFleetCost` para `int?`;
`diasRestantes` para `int?`; e a mensagem falsa do `licenca_banner.dart:52`.

### ⬜ T10 — A app passa a falar português
`flutter_localizations`, os dois date pickers, os enums crus no ecrã, e
`euros(int?)` a substituir os oito `toStringAsFixed(2)`.

### ⬜ T11 — Bug do veículo e duplo submit
**Paragem no passo 1**: mapeio o caminho completo e mostro-te a divergência
antes de mexer. Só fecha quando o vir desaparecer no aparelho — o teste
unitário já passa e o bug existe à mesma.

### ⬜ T12 — Estados vazios e destino dos conflitos
Seis listas sem estado vazio. **Paragem condicional no passo 2**: se ligar os
conflitos for mais de um dia, paro — a alternativa é apagar 430 linhas e essa
decisão é tua.

### ⬜ T13 — Custo de estrutura no ecrã
O motor está completo e testado; falta o ecrã. É a que recupera mais promessa
por menos trabalho.

### ⬜ T14 — Contabilista ligado aos KPIs
**Duas paragens**: mostro-te primeiro o mapa rubricas → `HistoricalMonth`, e
pergunto a regra de precedência quando o gestor já preencheu o mês à mão.

---

## Fora das catorze

- [ ] `scripts/update-release-catalog.sh` **do Punho** tem o mesmo defeito
      POST-vs-PATCH que já corrigi no do Punho OP: repetir para um build já
      catalogado morre com *"build_number tem que ser > max existente"*. O
      comentário no topo promete que pode ser repetido — hoje é mentira.
- [ ] O Redmi tem a **0.3.2+37**; a versão publicada é a **0.3.3+38**. Bom
      momento para provar o auto-update de ponta a ponta.
