# Estado atual do Punho

> **Release v0.3.3** (tag `v0.3.3`, `version: 0.3.3+38`) — 8 de agosto de 2026
>
> A cadeia de publicação foi provada de ponta a ponta em aparelho real: a
> 0.3.2+37 instalada no Redmi recebeu o aviso, descarregou, verificou o
> `sha256` e instalou a 0.3.3+38 pelo instalador do sistema, sem cair para o
> browser. Ficou também documentado o que **não** é nosso e trava à mesma: o
> Google Play Protect exige que cada cliente mande o APK para análise a cada
> actualização, e não oferece "instalar mesmo assim" — ver
> `docs/SMOKE.md`, ponto 11.
>
> Publicar e anunciar passaram a ser dois comandos (`release.sh` pára na
> GitHub Release; `update-release-catalog.sh` é que faz a versão chegar aos
> telemóveis), com `docs/SMOKE.md` entre os dois e um `--ensaio` que corre
> tudo sem deixar rasto. Runbook único: `docs/PUBLICAR_RELEASE.md`.
>
> Correcções que mudam o que o cliente vê: o dinheiro deixou de virar zero em
> silêncio (custos fixos recusam gravar um valor inválido em vez de o
> substituírem por zero; o custo de frota distingue "por apurar" de "zero
> euros"), e a `validar-licenca` deixou de dar uma licença por expirada
> durante todo o último dia em que ainda era válida — defeito que afectava
> também o WashInvoice POS. Ver `docs/LICENCIAMENTO.md`.
>
> Fecho de segurança e de infra: funções e recursos expostos ao papel `anon`
> fechados e provados (HTTP 401/42501), `allowBackup="false"` mais regras de
> extracção — com o cadeado provado **no aparelho** por `integration_test`,
> não só por testes unitários — e uma CI só de verificação
> (`.github/workflows/verificar.yml`: `analyze` + `test`, nunca compilar nem
> assinar). O plano vivo do que falta está em
> `docs/PLANO_TAREFAS_2026-08-08.md`.

> **Release v0.2.0** (tag `v0.2.0`, `version: 0.2.0+33`) — 3 de agosto de 2026
>
> Sincronização automática de custos fixos e de dados da empresa — deixa de
> depender de botão manual — e o cartão "Previsão do mês" em Finanças, que soma
> o que falta receber nas reservas já marcadas aos custos fixos e à média de
> despesas variáveis recentes, sem inventar clientes novos. Publicada pela
> cadeia completa (APK + GitHub Release + `versoes_apps`), a pedido do Cesar —
> ver `docs/release_notes/v0.2.0.md`.
>
> Inclui também a Fase 0 da infra-estrutura de conflitos de reserva entre
> colaboradores offline (`786d845`): modelo `ConflitoPendente` com id
> determinístico, registo e sincronização próprios, tabela
> `punho_conflitos_pendentes` com RLS (SELECT aberto a qualquer membro activo,
> INSERT/UPDATE só Gestor — mesmo padrão de `punho_estado_operacional`). É
> infra inerte por construção, não muda nenhum comportamento visível: a
> deteção real dentro de `aplicarOperacaoRemota` (hoje aceita cegamente, "quem
> chega depois fica por cima") e o banner de decisão do Gestor ficam para uma
> iteração futura, a pedido.
>
> Dois achados fora do ciclo de features: o workflow antigo do GitHub Actions
> foi removido (`65fae4e`) — a publicação passa a ser inteiramente manual a
> partir do i9, nunca mais por push de tag; e um achado de segurança real
> (`224853d`) em que a RLS de pedidos_ajuda/sugestoes deixava ler/alterar
> pedidos de outra empresa e o `nif` vinha do que o próprio pedido dizia —
> corrigido na Supabase (RLS + trigger a resolver sempre por `licencas`) e no
> cliente, que passa a identificar-se por `machine_id`. Ícone adaptativo e
> splash regenerados nesta sessão (`beb6cd1`), sem mudança de lógica.

> **Releases v0.1.5 a v0.1.11 — 2 e 3 de agosto de 2026** (fecho técnico da
> campanha de testes, abaixo)
>
> Sete releases em sequência rápida — só `v0.1.5` e `v0.1.11` têm notas
> individuais em `docs/release_notes/`; `v0.1.6` a `v0.1.10` não têm. Fecham
> os achados da campanha de 2 de agosto: o "zero calado" do dinheiro corrigido
> em oito sítios (reservas, despesas, recebimentos, custo de colaborador,
> prestação e seguro de veículo passam todos por `centsDeTexto`, que recusa
> gravar em vez de inventar zero), aviso de valor inválido a sair do
> `SnackBar` para junto do campo, máquina alugada a bloquear só a data
> ocupada em vez de todas as semanas seguintes, selector de reservas a voltar
> a mostrar o nome da máquina mesmo com referência, despesas/recebimentos por
> data e clientes por ordem alfabética, cálculo da "última quarta-feira"
> corrigido para segunda e terça-feira, e o NIF a passar a obrigatório tanto
> no onboarding como em Definições da Empresa — resolve os 400 da Edge
> Function `sincronizar-empresa-punho` para quem terminava sem NIF. Do lado
> do servidor, `registar-terminal` passa a actualizar `licencas.nif` com o
> NIF real assim que a app o tem (`1e0c04d`) — nenhuma instalação Punho
> alguma vez tinha ligado o NIF real à sua licença antes disto.
>
> Três hotfixes no mesmo dia (`v0.1.7`, `v0.1.8`, `v0.1.9`, tags directas sem
> `chore(release)` próprio) forçam retrato em toda a sequência do instalador
> de update — o Play Protect e o instalador do sistema não sabem lidar com
> landscape — e dão um X para dispensar o aviso opcional até à próxima
> entrada na app. `v0.1.10` traz a limpeza dos 8 avisos que bloqueavam
> `flutter analyze --fatal-infos` e dois fixes ao script de catálogo de
> releases: nome do asset Android alinhado com o workflow (deixou de esperar
> `Punho_v..._universal.apk`/`.exe`, que já não existem) e publicação do
> sha256, sem o qual o botão "Atualizar" caía sempre para o browser externo
> em vez de instalar in-app. `v0.1.11` acrescenta custos fixos editáveis por
> rubrica, veículos a mostrar o custo total (prestação + seguro + manutenção,
> com campo novo para a manutenção anual prevista), o motor de recomendações
> fundido num só (dashboard e Tarefas deixam de poder contradizer-se),
> cadeado com opção de 2 minutos como novo default e botão de Sugestões no
> Perfil, a escrever na mesma tabela do Control que já recebe as do
> WashInvoice. Ver `docs/release_notes/v0.1.5.md` e
> `docs/release_notes/v0.1.11.md`.

> **Campanha de testes no telemóvel — 2 de agosto de 2026** (v0.1.4+25, Redmi
> Note 10 Pro)
>
> Primeira vez que a app foi posta à prova de ponta a ponta num aparelho real,
> com onboarding completo de um empresário simulado e dados semeados no
> servidor. Achado maior: **a sincronização entre dispositivos nunca tinha
> corrido nenhuma vez desde que existe** — um bug silencioso mantinha o motor
> sempre parado. Corrigido, tal como a campainha em tempo real (também nunca
> tinha tocado) e a rotação indevida do ecrã no arranque; os três já estão
> commitados. Fica ainda por commitar um lote de correcções verificadas no
> aparelho: ecrã vermelho ao gravar cliente, avisos de recusa que ficavam
> escondidos atrás do teclado, cabeçalhos cortados pela barra de estado e
> copy desactualizada. Checklist completa e achados 6–21 em
> `docs/PLANO_DE_TESTES_2026-08-02.md`.
>
> Ficou por resolver, e não é bug de implementação mas decisão de desenho: uma
> máquina alugada bloqueia hoje **todas** as semanas seguintes, não só a data
> ocupada — decisão já tomada (bloquear só a data), por implementar.
>
> **Sprint v0.0.5 · painel em carrossel** (branch `feat/v005-dashboard-alavancas`)
>
> O painel de gestao deixou de ser 17 metricas num Wrap e passou a cinco slides
> com quatro KPIs cada, um por pergunta de gestao. Nenhuma metrica se perdeu:
> a lista completa esta em "Ver todas as metricas". Barra lateral a 88 dp com
> rotulos, destinos novos **Financas** e **Tarefas** (com contagem de
> pendencias), e a app passou a ser so landscape. Suite 203 -> 284. Ver
> `design/punho_v005_dashboard.md`.
>
> Zeros falsos eliminados: um valor que e zero por falta de dados aparece como
> "Por apurar" com a razao, nao como 0 €.

> **Release v0.0.3 consolidada** (branch `release/v0.0.3`, `version: 0.0.3+3`)
>
> Junta a sprint de estabilizacao (abaixo) com o **aviso de update global**,
> antecipado da v0.0.4. O aviso deixou de depender de sessao e de ecra: antes so
> um gestor com adesao activa que abrisse o dashboard o via, agora chega a quem
> esta no login e a quem esta bloqueado no gate (pedido pendente, acesso
> recusado ou revogado). Suite de testes 162 -> 177. Ver
> `design/punho_v003_update_global.md`.
>
> **A v0.0.3 tem de ser instalada por USB** — a v0.0.2 no Redmi nao sabe
> verificar updates fora do dashboard. E a ultima instalacao manual: a partir
> daqui as versoes chegam pelo aviso na app.

> **Sprint de estabilizacao v0.0.3** (branch `chore/estabilizacao-v0.0.3`)
>
> Foi estabilizacao pura: **o ambito de "utilizacao real" nao mudou**. Nada
> passou de "modo demonstracao" para "utilizavel com dados reais" — as
> correccoes foram de bugs, nao de ligacao a dados novos.
>
> O que mudou de facto: o perfil aprovado em `punho_membros` passa a escolher a
> shell, pelo que um colaborador ja nao recebe a vista de gestor com custos,
> salarios e lucros globais (era P0). Corrigidos mais 2 P0 e 8 P1. Suite de
> testes 106 -> 162. Ver `AUDITORIA_BUGS_v0.0.3.md`.
>
> **Smoke manual dos 9 fluxos: por fazer.** Ate estar assinado na auditoria,
> nada disto conta como validado.

## Ja utilizavel no modo demonstracao local

- Onboarding guiado da empresa, forma juridica, equipa, frota e numero estimado de maquinas.
- Inventario de maquinas identificadas, estado, referencia e categoria.
- Clientes partilhados pela empresa e leads convertiveis em clientes.
- Reservas com cliente, maquina, periodo, valor previsto, estado e responsavel.
- Bloqueio de sobreposicao de maquinas em reservas confirmadas ou em aluguer.
- Registo de despesas, recebimentos, pagamentos pendentes e ligacao de recebimento a reserva.
- Custos estimados de colaboradores e frota, incluindo custo/hora e seguros anual/semestral mensalizados.
- Area de colaborador para criar leads, pedidos de reserva e recebimentos, sem acesso aos custos da empresa.
- Painel de gestao com indicadores e recomendacoes deterministicas.
- Dados de onboarding e operacao guardados no proprio dispositivo entre reinicios.
- Aviso de nova versao publicada, em qualquer ecra e sem precisar de sessao —
  inclui quem esta bloqueado no gate de acesso. Update obrigatorio bloqueia a
  app. Depende do Cesar publicar em `versoes_apps`; a app so avisa, nao instala.

## Ja preparado para a aplicacao real

- Autenticacao Supabase, confirmacao de adesao a empresa e logout.
- Migration para onboarding atomico, RLS inicial e protecoes entre empresas.
- Modelos de outbox e idempotencia para a sincronizacao futura.
- Sincronizacao remota segura do estado completo do gestor, com revisao de conflitos. **Verificada de ponta a ponta no aparelho em 2 de agosto de 2026** (envio, recepcao e campainha em tempo real nos dois sentidos); falta ainda a granularidade por entidade/perfil e a resolucao de conflitos.

## Ainda nao usar com dados reais

- Os repositorios de clientes, maquinas, reservas, financas, equipa e frota ainda nao escrevem em tabelas Supabase individuais; nesta fase o gestor sincroniza um estado operacional protegido.
- Nao ha sincronizacao granular de colaboradores, convidados reais, autorizacao pelo WashInvoice Control, camera/OCR real ou distribuicao Android validada.

## Proxima prioridade tecnica

A ligacao ao Supabase e a outbox local ja existem e ja foram verificadas a
funcionar de ponta a ponta num aparelho real (2 de agosto de 2026). O lote de
correccoes encontradas nessa campanha (selector de maquina, ordenacao de
listas, "ultima quarta-feira", NIF obrigatorio, PIN 1234, aviso de limite de
colaboradores) ja foi commitado e publicado entre 2 e 3 de agosto, releases
v0.1.5 a v0.1.11 (ver acima) — confirmado no aparelho real, sem regressoes
(`docs/PLANO_DE_TESTES_2026-08-02.md`). Fica por resolver: a origem/campanha
da lead nunca e perguntada (achado da auditoria, eixo 2) e um overflow
cosmetico em dois dialogos (Mudar palavra-passe, Definir PIN) so visto em
build debug, sem decisao tomada sobre corrigir.

A Fase 0 da infra de conflitos entre dispositivos offline (v0.2.0, `786d845`)
já está commitada, mas é inerte por construção — não muda nada visível. A
prioridade seguinte nessa frente é a Fase 1: a deteção real dentro de
`aplicarOperacaoRemota` e o banner de decisão do Gestor; fica para quando for
pedida, não é hoje prioridade imediata face ao lote de correcções acima.
