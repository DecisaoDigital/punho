# Estado atual do Punho

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
- Sincronizacao remota segura do estado completo do gestor, com revisao de conflitos.

## Ainda nao usar com dados reais

- Os repositorios de clientes, maquinas, reservas, financas, equipa e frota ainda nao escrevem em tabelas Supabase individuais; nesta fase o gestor sincroniza um estado operacional protegido.
- Nao ha sincronizacao granular de colaboradores, convidados reais, autorizacao pelo WashInvoice Control, camera/OCR real ou distribuicao Android validada.

## Proxima prioridade tecnica

Ligar os repositorios operacionais ao Supabase e guardar uma outbox local persistente. Sem isso, nao ha piloto real multi-dispositivo.
