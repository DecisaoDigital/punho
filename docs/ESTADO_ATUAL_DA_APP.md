# Estado actual — Punho

Actualizado: 2026-07-29
Versão pubspec (branch `main`): **0.0.8+8**
Último release publicado (tag GitHub): **v0.0.8** (2026-07-28)

> Este ficheiro é o resumo do estado real do produto. Para o histórico
> cronológico por sprint ver `DECISOES_E_ROADMAP_VIVO.md`.

---

## O que já funciona

### Shell e navegação (v0.0.8)
- Barra lateral fixa com **7 destinos** por esta ordem (`lib/core/navigation/app_destination.dart`):
  Painel, Máquinas, Reservas, Clientes, Colaboradores, Empresa, Tarefas.
- Vocabulário revisto na v0.0.8 (Decisão 2): "Gestão" → **Painel**, "Frota" → **Veículos**, "Funcionários" → **Colaboradores**.
- Destinos legados (`finances`, `vehicles`) continuam no enum e abrem a aba certa dentro de **Empresa** — os saltos antigos não rebentam.
- Ecrã **Empresa** com 6 abas: Dados · Regime · Custos fixos · Veículos · Finanças · Estado (`AbaDaEmpresa`).
- Toda a app em landscape excepto o painel do gestor (Decisão 13).
- Popup Perfil no avatar da sidebar (chip `SESSÃO ACTIVA` / `MODO DEMONSTRAÇÃO`, terminar sessão).

### Painel de gestão (v0.0.5)
- Carrossel com **5 slides × 4 KPIs**, cada slide responde a uma pergunta de gestão:
  `dinheiro_slide.dart`, `pipeline_slide.dart`, `rentabilidade_slide.dart`, `custos_slide.dart`, `semana_slide.dart`.
- `TodasMetricasPage` consome os mesmos KPIs puros (sem duplicar contas).
- Recomendação do dia com bordo verde/laranja/vermelho por gravidade.
- Zeros falsos eliminados: falta de dados aparece como "Por apurar" com a razão.

### Onboarding e operação
- Onboarding guiado (empresa, forma jurídica, NIF, equipa, frota, máquinas). Valores desconhecidos ficam em **Dados por completar**, não bloqueiam.
- Ecrãs de contexto `MaisDadosScreen` + `BoasVindasScreen` no fim (portrait, CTA para rodar tablet).
- Clientes, leads e conversão de lead em cliente.
- Máquinas com foto local, estado clicável, botão eliminar com undo 6 s.
- Reservas com bloqueio de sobreposição, meio-dia mínimo, agenda semanal centrada na máquina.
- Colaboradores com **modelo contratual** (`EmploymentType.recibosVerdes` / `contrato`), campos condicionais e KPI "Custo real com pessoal" (bruto + TSU patronal 23,75%).
- Ficha fiscal por vínculo, com custo real visível.
- Estimativas fiscais (`estimarSalarial`) são funções puras que nunca guardam resultado.
- Despesa a partir de fotografia da fatura (QR AT lido no dispositivo).
- Fotografias de máquinas e comprovativos de despesa em Supabase Storage privado.
- Colaborador em modo local regista leads, reservas, recebimentos e despesas sem ver custos globais.

### Auth e acessos (v0.0.7)
- Auth Supabase com mensagens granulares no registo (email já com conta, palavra-passe curta, rate limit, registo desactivado).
- Ecrã de sucesso após pedir acesso (deixa de ficar preso no formulário).
- Diagnóstico do verificador de actualizações (registava falhas em silêncio; agora vão para log).
- `AcessoGate` decide shell pelo perfil aprovado em `punho_membros`.
- Convites e ecrã de pedido em análise.

### Backend Supabase (`oefqbkhioncakojipqyx`)
- Schema Punho completo em produção: 8 migrations aplicadas (`punho_core`, `punho_rls_completion`, `punho_onboarding_rpc`, `punho_auth_and_rls_hardening`, `punho_operational_state_sync`, `punho_pedidos_acesso`, `punho_contas_organizacao`, `punho_aprovacao_pelo_control`).
- Trigger `AFTER INSERT ON auth.users` filtra `raw_user_meta_data->>'app' = 'punho'` e cria pedido de acesso.
- Trigger `AFTER INSERT ON punho_pedidos_acesso` chama edge `enviar-push` (#196).
- `punho_criar_empresa_inicial` **revogada de `authenticated`** — criar empresa passa a ser exclusivo do Control via RPC `security definer`.
- RPCs `punho_meu_acesso`, `punho_validar_convite`, `punho_criar_convite`, `punho_decidir_pedido`, `punho_listar_pedidos_admin`, `punho_listar_empresas_admin`.

### Licenciamento
- Cliente de licenciamento inicial ligado ao padrão multi-app do Control, com trial técnico. Ver `LICENCIAMENTO.md`.
- Banner de licença acima do conteúdo em todos os ecrãs; encolhe a zero quando tudo bem.

### Update banner
- Aviso de nova versão publicada em qualquer ecrã e sem precisar de sessão (inclui gate de acesso).
- Update obrigatório bloqueia a app. A app só avisa, não instala.

### Testes
- Última contagem confirmada nos release notes: **460 testes** (v0.0.7).

---

## O que está a meio (WIP)

- Branch actual **`feat/v008-sidebar-empresa`** — sidebar refactorizada + ecrã Empresa entregues, bump pubspec e docs de release por fechar.
- Sprint 3+4 do v0.0.5 anotada como aberta em `DECISOES_E_ROADMAP_VIVO.md` §3.5:
  - Placeholders de máquinas a partir do onboarding.
  - `_machineDialog` largo em duas colunas landscape.
  - `_collaboratorDialog` / `_vehicleDialog` acima do teclado em portrait.
  - `BookingsPage` limpa com calendário sem scroll.
  - Onboarding: revisão dos sub-textos dos 12 passos.
  - Funcionários editáveis + coluna "vendas do mês por colaborador".
- Task **#203** — refactor do dashboard para 9 slides (2 operacionais + 5 alavancas + 1 direcção + 1 previsibilidade). Racional literal do Cesar em `GUIAO_DE_PERCURSO_PRIMEIRO_EMPRESARIO.md` (Decisões 6-10). Depende da Task #199 (sidebar) — que ficou fechada com a v0.0.8. Ver `outputs/BRAINSTORM_DASHBOARD_9_SCREENS_2026-07-29.md`.
- Sprint 2 v0.0.6 self-service do colaborador — RPC `punho_atualizar_ficha_colaborador`, trigger de push na transição NISS null→preenchido, chips `FICHA COMPLETA` / `AGUARDA COLABORADOR`.
- Task **#204** — Tarefas como backlog priorizado.

---

## O que ainda não existe

- Sincronização real multi-dispositivo por entidade + outbox persistente (repositórios de clientes, máquinas, reservas, finanças, equipa e frota ainda não escrevem em tabelas Supabase individuais — o gestor sincroniza um estado operacional protegido).
- Registo estruturado de reclamações ligado a máquina/cliente/reserva.
- Painel clicável de funil, publicidade, retorno de clientes com listas accionáveis.
- Cálculo de margem por reserva/máquina/cliente/origem/colaborador.
- Previsão de tesouraria e cenários.
- **Slide 9 — Previsibilidade Simulada** (Decisão 10, `Simulador` como motor puro).
- **Modelo `ObjetivoAnual`** e slide Objectivos (Decisão 9).
- Novos KPIs previstos no dashboard 9 slides: `entregasHoje`, `devolucoesHoje`, `devolucoesEmAtraso`, `cobrancasNaProximaSemana`, `alertasOperacionais`, `progressoObjetivo`, `ritmoNecessarioParaAlvo`, `alavancaMaisRelevanteParaObjetivo`, `utilizacaoVsRentabilidadeMaquinasMes`.
- WhatsApp manual com mensagens preparadas e histórico de contacto (fase 1 do §8.1).
- Punho IA Pro (§8.2).
- Balanço de Comando (proposta ao fim de ~1 ano de uso — §9).
- Regimes especiais (TSU reduzida para pensionistas, isenção IRS de jovens, subsídios de férias/Natal) — explicitamente fora até decisão.
- Reactivar máquina como acção explícita na ficha.
- 6ª alavanca do dashboard (candidato: Balanço de Comando / Aprendizagem) — por nomear.

---

## Bugs conhecidos abertos

- Ficha do colaborador editável — inclui na sprint 3+4 v0.0.5 (WIP).
- Placeholders de máquinas do onboarding não criam linhas editáveis com flag `placeholder` (WIP).
- 6ª alavanca por decidir + destino do slide Previsibilidade — ver "Pontos abertos" em `outputs/BRAINSTORM_DASHBOARD_9_SCREENS_2026-07-29.md`.

---

## Próximos passos priorizados

1. **Fechar v0.0.8** — bump pubspec `0.0.7+7 → 0.0.8+8` na branch, notas de release e merge.
2. **Sprint 3+4 v0.0.5** (placeholders, diálogos largos, BookingsPage limpa, funcionários editáveis).
3. **Task #203** — refactor do dashboard em 9 slides (renomear `dinheiro_slide.dart` → `sintese_slide.dart`, criar `operacional_slide.dart`, `procura_slide.dart`, `tesouraria_slide.dart`, `margem_slide.dart`, `frota_slide.dart`, `equipa_slide.dart`, `objetivos_slide.dart`, `previsibilidade_slide.dart`; widget `SlideAlavanca`).
4. **Sprint 2 v0.0.6** — self-service do colaborador (RPC + trigger + chips).
5. **Sincronização real** por entidade (destranca piloto multi-dispositivo).

---

## Referências

- Decisões e roadmap vivo: `docs/DECISOES_E_ROADMAP_VIVO.md`.
- Arquitectura do dashboard 9 slides: `docs/GUIAO_DE_PERCURSO_PRIMEIRO_EMPRESARIO.md` (Decisões 6-10) e `outputs/BRAINSTORM_DASHBOARD_9_SCREENS_2026-07-29.md`.
- Release notes: `docs/release_notes/v006.md`, `docs/release_notes/v007.md`.
- Handover da sessão anterior: `docs/HANDOVER_SESSAO_SEGUINTE.md` (data 27/07 — stale, pré-v0.0.8).
- Licenciamento: `docs/LICENCIAMENTO.md`.
- Auditoria .md vs código de 2026-07-29: `outputs/AUDITORIA_MD_vs_CODIGO_2026-07-29.md`.
- Contexto do projecto: skill `/washinvoice` (que inclui Punho no mesmo ecossistema).
