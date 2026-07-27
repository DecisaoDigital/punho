# Punho — checklist da 0.0.6 sprint 1 até ao fim do horizonte planeado

> Consolidação de tudo o que está por implementar, por ordem de
> prioridade. Consulta o `GUIAO_DE_PERCURSO_PRIMEIRO_EMPRESARIO.md`
> para o racional de cada decisão referenciada.

## Prioridade 1 — Fechar release v0.0.6 (URGÊNCIA · fix de landscape para o Redmi do Cesar)

- [x] Frente A · Boas-vindas + MaisDados (`feat/v006-boas-vindas`)
- [x] Motor fiscal · `RegimeFiscal` + `estimarSalarial` + tabelas IRS
- [x] Frente D · KPI "Custo real com pessoal"
- [x] **Frente C UI** · `FichaFiscalColaboradorForm`, `SegmentedButton`, chips NISS/NIF (`ee248b4` + `2bb3535`)
- [x] **Follow-up Decisão 12** · `CustosMes.totalCents` sensível ao regime (`babb2b5`)
- [x] **Follow-up Decisão 13** · `OrientacaoDoContexto` + portrait/landscape por contexto (`ffe917d`)
- [x] **Frente B · Popup Perfil** — avatar da sidebar abre popup com identidade, sessão e sair (`f23ee02`)
- [x] **Auditoria hit target (task #206)** — 6/7 grupos já cumpriam via Material; único caso real (avatar) resolveu-se no Passo 5. Testes reforçados a medir geometria em vez de "não lança excepção" (`60ed6f2`)
- [x] Doc `docs/design/punho_v006_sprint1.md` (untracked, entra no commit de release)
- [ ] **Release v0.0.6** (dry-run workflow, NDK #197, CI #202, bump 0.0.6+6, commit CRLF-safe, tag, push, APK, INSERT `versoes_apps`)

## Prioridade 2 — Sprint 2 v0.0.6 (self-service do colaborador)

Ficheiro: `prompts/punho_v006_sprint2_colaborador_selfservice.md`.

- [ ] Card âmbar no shell colaborador *"A tua ficha está incompleta"*
- [ ] `FichaFiscalColaboradorFormPage` reusando o widget da 1-C
- [ ] Novos campos no `Collaborator`: IBAN, morada pessoal, data
      nascimento
- [ ] RPC Supabase `punho_atualizar_ficha_colaborador` (security
      definer, colaborador só mexe nos campos permitidos)
- [ ] Trigger `AFTER UPDATE` dispara push ao gestor na transição
      `NISS null → preenchido`
- [ ] Chip verde `FICHA COMPLETA` / âmbar `AGUARDA COLABORADOR` na
      `CollaboratorsPage`

## Prioridade 3 — Cesar: instalar Control 1.8.1 no Redmi (task #188)

Sem isto, os push do trigger #196 (novo pedido Punho) e o da sprint 2
(ficha completada) chegam ao vazio. Bloqueia validação real de tudo o
que vem por push.

- [ ] Merge `feat/aprovar-pedidos-punho`
- [ ] Compilar APK Control 1.8.1
- [ ] Instalar no Redmi
- [ ] Registar token FCM em `admin_dispositivos`
- [ ] Verificar recepção do push com sonda SQL

## Prioridade 4 — Sprint 3 v0.0.6 (WhatsApp + retorno clientes)

Ficheiro: `prompts/punho_v006_sprint3_whatsapp_retorno.md`.

- [ ] Serviço partilhado `WhatsAppMessenger`
- [ ] Mensagens preparadas na reserva (5 tipos: confirmação · pedido
      confirmação · lembrete levantamento · lembrete devolução ·
      cobrança), templates editáveis por empresa
- [ ] Painel `RetornoClientesPage` (>18d / >40d sem regressar) com
      botão "Reengajar" via WhatsApp
- [ ] KPI "Clientes a reengajar" no slide de Procura e vendas
- [ ] `Communication` (intenção de contacto) — só regista o *abriu
      WhatsApp*, não o envio real

## Prioridade 5 — Higiene + UX pequena com alto impacto

- [ ] **#200** · Rótulo permanente da app no canto inferior esquerdo
      (Decisão 3) — 30 min de trabalho, visível em toda a app
- [ ] **#197** · NDK 27.0.12077973 no `build.gradle.kts` — antes do
      QR facturas ser usado a sério
- [ ] **#202** · CI: excluir tests de screenshot do gate de release
- [ ] **#198** · Cesar: `gh auth login` no Punho para releases
      explícitas

## Prioridade 6 — Refactors grandes que reformulam a app

O coração pedagógico e a arquitectura de informação.

### 6a. Task #199 · Arquitectura da sidebar (Decisão 2)

- [ ] Renomear: `Gestão` → `Painel`; `Frota` → `Veículos`;
      `Funcionários` → `Colaboradores`
- [ ] Novo destino `Empresa` com abas (Dados · Regime fiscal ·
      Custos fixos · Veículos · Finanças · Estado)
- [ ] Migrar `VehiclesPage` + Finanças + Custos fixos para dentro
- [ ] `Colaboradores` mantém-se destino próprio
- [ ] Popup Perfil no avatar (ampliação da Frente B da sprint 1)

### 6b. Task #203 · Refactor do Dashboard em 9 slides (Decisões 6-10)

- [ ] Slide 1 · Primeiro impulso (Decisão 6)
- [ ] Slide 2 · Operacional (Decisão 8)
- [ ] Slides 3-7 · 5 Alavancas (Decisão 7)
- [ ] Slide 8 · Objectivos (Decisão 9) + modelo `ObjetivoAnual` + tab
      em Empresa
- [ ] Slide 9 · Previsibilidade Simulada (Decisão 10) com campos
      editáveis in-line + motor `Simulador`
- [ ] Widget partilhado `SlideAlavanca`
- [ ] Todos os KPIs "por apurar" apontam para Tarefas

### 6c. Task #204 · Tarefas como backlog priorizado de perguntas (Decisão 11)

- [ ] Modelo `Pergunta` com flag `é_veracidade`
- [ ] Motor `PriorizadorDePerguntas` (verdade > eficiência > urgência
      > antiguidade)
- [ ] Refactor `TarefasPage` com selos coloridos (vermelho / verde /
      âmbar)
- [ ] Estatística no topo: N perguntas por responder + % KPIs
      completos
- [ ] Botão "Ver KPIs por apurar"

### 6d. Motor fiscal completo `RegimeFiscal` (Decisão 1)

Sprint separada, depois dos 3 refactors acima.

- [ ] Enum `RegimeFiscal` completo (hoje temos só mínimo do
      `estimarSalarial`)
- [ ] Todos os KPIs financeiros passam a consultar o regime
- [ ] KPIs que não se aplicam ao regime ficam ocultos (não a "0 €")

## Prioridade 7 — Segurança (Task #201, Decisão 4)

Depois da app estabilizar em UX. Sprint dedicada.

- [ ] `local_auth` + `flutter_secure_storage`
- [ ] `LockScreen` que intercepta o `AuthGate`
- [ ] Biometria por defeito + PIN 4-6 dígitos fallback
- [ ] Timeout inactividade configurável (default 15 min)
- [ ] 3 tentativas erradas → bloqueio → re-auth Supabase com
      autofill biométrico do SO
- [ ] Setup opt-in com nudge na primeira sessão

## Prioridade 8 — Longo prazo (v0.1.x, v1.x, v2.x)

Não são para esta janela, ficam marcados como norte.

- [ ] **Painel Estado** (Aposta B da auditoria fora-da-caixa) —
      timeline de IVA/IRC/TSU/IRS; encaixa na aba `Estado` do
      destino Empresa
- [ ] **Correlação clima × ocupação** (Aposta C) — IPMA grátis,
      recomendação nova no Slide Operacional
- [ ] **Post-mortem de decisões** (Decisão 5, Aposta A) — norte de
      longo prazo, v1.x ou v2.x
- [ ] **Balanço de Comando** (Biblioteca de Alavancas) — após ~1
      ano de utilização real, encaixa com Slide de Objectivos
- [ ] **Sincronização multi-dispositivo real** por entidade (roadmap
      vivo P1)
- [ ] **RLS de produção + Storage privado**
- [ ] **Integração real com Control** para planos e limites de vagas

## Coisas fora do Punho, no calendário do Cesar

- [ ] **#52** · Segunda-feira: chamar `707 206 707` para credenciais
      de produtor de software (Modelo 24 WashInvoice)
- [ ] **#153, #167, #142** e outras do lado do POS — não fazem parte
      deste horizonte Punho

## Notas transversais para o Code (padrões a manter)

- `copyWith` com sentinela em vez de `?? this` (Decisão P2-5 já
  apanhada duas vezes).
- `TextEditingController.dispose` depois de `Navigator.pop` retornar,
  não durante a animação de fecho.
- `DialogoDeFormulario` de `core/layout` — usar quando o diálogo tiver
  mais que 3 campos ou for aberto em telemóvel.
- Ficheiros de screenshot com `@Tags(['screenshot'])` para o CI
  excluir (task #202).
- `RegimeFiscal` como parâmetro obrigatório de qualquer função nova
  de estimativa fiscal (Decisão 1).
