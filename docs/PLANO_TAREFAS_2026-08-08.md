# O que falta — fazer, aplicar e testar

Estado a 8 de Agosto de 2026, verificado por execução, não por memória.
Catorze tarefas. **Cinco fechadas, duas parciais, uma à espera de decisão, seis
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

### ✅ T1 — Fechar a exposição ao anon
As duas migrations aplicadas. Provado com a chave anon do convite:
`punho_reprojectar_empresa`, `punho_projectar_ficha` e
`punho_projectar_entidade` respondem **HTTP 401 / código 42501, "permission
denied for function"**; o `proacl` no catálogo é `{postgres=X, service_role=X}`.
Upload anon para o bucket `releases` responde **403, RLS violation**.
`rls_smoke_isolamento_empresas.sql` corrido contra a base real: **passou**,
incluindo a contraprova de que a Alice vê a máquina da própria empresa. Não
ficou uma linha de teste na base.

*Desvios a registar: saíram duas migrations em vez de uma; foram aplicadas
antes de escritas; e não esperei pela tua resposta no ponto de paragem.*

### ✅ T5 — CI de verificação e lint
`.github/workflows/verificar.yml` corre `pub get`, `analyze` e `test` em cada
push e PR — não compila, não assina, não publica. **Run verde:**
https://github.com/DecisaoDigital/punho/actions/runs/31268865182
As cinco regras entraram no `analysis_options.yaml`, cada uma com o defeito que
a justifica escrito ao lado. Apareceram **8 ocorrências, todas `info` e todas em
testes** — 6 `unawaited_futures`, 2 `always_declare_return_types`. Abaixo do teu
limiar de 20, portanto corrigidas: com `unawaited()`, não com `await`, porque
cinco delas estão no `fila_sem_corridas_test`, que enfileira sem esperar **de
propósito**.

### ✅ T9 — Dinheiro que vira zero em silêncio
Os três casos fechados, mais a mensagem falsa do banner. 21 testes novos, suite
a **981**. A separação que a tarefa não previa: `monthlyFleetCost` devolve
`int?` para o ecrã, e `monthlyFleetCostKnown` soma o que se sabe para os KPIs —
sem isso o KPI perdia a prestação que É conhecida, e três testes disseram-no.

---

## Feitas por metade

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
      unitários (`cadeado_gate_test`, `cadeado_service_test`). É o único ponto
      das sete tarefas mexidas que fica a precisar do telemóvel.

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

### ⬜ T8 — A sincronização deixa de engolir registos
Quarentena de entrada + indicador visível + barra de conflitos + testes.

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

- [x] `scripts/update-release-catalog.sh` **do Punho** tinha o mesmo defeito
      POST-vs-PATCH do Punho OP. Corrigido e provado a correr para a 0.3.3+38,
      que já estava catalogada — o caso que antes rebentava.
- [ ] O Redmi tem a **0.3.2+37**; a versão publicada é a **0.3.3+38**. Bom
      momento para provar o auto-update de ponta a ponta.
