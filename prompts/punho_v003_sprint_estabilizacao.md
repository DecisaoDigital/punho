# Prompt Claude Code — Punho v0.0.3 (sprint de estabilização)

## Objectivo

O Cesar vai apresentar o Punho a um cliente potencial importante. O produto ainda não vai a produção, mas **vai representar a Decisão Digital** — não pode ter bugs no happy path.

Este sprint **não adiciona features novas**. É bug hunt sistemático, correcção do que rebentar, e cobertura de testes onde falta. Termina com um standard mínimo: **zero bugs P0/P1 conhecidos no happy path**.

**Repo:** `punho`, branch nova `chore/estabilizacao-v0.0.3` a partir da `feat/contas-organizacao` (assumindo que essa está mergeda ou é a base actual). Confirma no início.

---

## Pré-requisito

A task anterior (`feat/contas-organizacao`, prompt `punho_v002_contas_por_organizacao.md`) tem que estar terminada. Se não estiver, para e reporta.

---

## Fase 1 — Bug hunt sistemático

Percorre a app corrida em `flutter run -d windows` E `flutter run -d chrome` (redimensiona para 411×900 para simular Android). Para cada fluxo abaixo, regista em `docs/AUDITORIA_BUGS_v0.0.3.md`:
- O que fizeste
- O que aconteceu
- O que devia ter acontecido
- Categoria: **P0 crash / erro visível**, **P1 dados errados / botão sem efeito / navegação partida**, **P2 cosmético**
- Ficheiro e linha (se conseguires localizar)

**Fluxos a cobrir (happy path):**

1. **Auth** — registo novo (com e sem convite), login, logout, ecrã "Pedido em análise", ecrã "Acesso indisponível"
2. **Onboarding empresa** — completar todos os campos, e depois **completar deixando campos em branco** (vai para "Dados por completar")
3. **Clientes** — criar, editar, tentar duplicado por telemóvel/NIF, converter lead em cliente
4. **Máquinas** — criar, editar, mudar estados (disponível/reservada/alugada/manutenção/parada), tentar mudar estado ilegal (ex: disponível quando tem reserva activa)
5. **Reservas** — criar (via cliente + máquina), tentar sobreposição de máquina, confirmar, iniciar aluguer, concluir, cancelar
6. **Financeiro** — registar recebimento (ligado e não-ligado a reserva), registar despesa, registar pagamento pendente, marcar como pago
7. **Colaborador** (área de funcionário) — criar lead, criar pedido de reserva, registar recebimento; **verificar que não vê custos, salários, lucros globais** (isto é crítico)
8. **Dashboard** — abrir com estado vazio (empresa nova), com estado povoado, ver recomendações determinísticas, ver frase/objectivo da semana
9. **Histórico mensal** — abrir, preencher um mês antigo, ver comparação homóloga aparecer no dashboard

**Edge cases a testar em cada fluxo:**
- Sem rede (activar modo avião ou mock)
- Sessão expirada a meio da acção
- Dois cliques rápidos no mesmo botão (double-tap)
- Rotação portrait ↔ landscape em mobile
- Estado vazio (nunca ninguém adicionou nada)

---

## Fase 2 — Bug crítico específico já conhecido

**Fix obrigatório nesta task:** `lib/features/shell/presentation/app_shell.dart` linhas 27-29 (verifica com grep se as linhas mudaram) — actualmente ignora o perfil do utilizador. Com Supabase activo, um colaborador aprovado recebe a `AppShell` de gestor em vez de `CollaboratorShell`.

**Impacto:** viola directamente o princípio "colaborador não vê custos/salários" (`AUDITORIA_E_PLANO_DO_PRODUTO.md` §4.2). É risco reputacional se um cliente descobre.

**Fix:** o router/shell tem que consultar o `perfil` da linha em `punho_membros` do utilizador autenticado e escolher `AppShell` (gestor) ou `CollaboratorShell` (colaborador). Adicionar widget test que confirma o dispatching correcto para os dois perfis.

Regista este fix como entrada primeira no `AUDITORIA_BUGS_v0.0.3.md` (P0), à parte dos bugs que descobrires nos fluxos.

---

## Fase 3 — Fixar todos os P0 e P1

Ordena por P0 → P1. Para cada um:
1. Reproduz o bug (screenshot ou trace).
2. Localiza root cause (não o sintoma).
3. Corrige.
4. Escreve teste que capturava o bug antes do fix.
5. Confirma o fix com o teste + smoke manual.
6. Actualiza a entrada no doc de auditoria: "**FIXED** (commit `<sha>`)".

**Regra 3-fix arquitectura:** se um bug precisa de 3 tentativas para ser resolvido, para e reporta. Provavelmente indica problema mais profundo que precisa de discussão.

**P2 cosméticos:** não são âmbito desta task. Ficam no doc de auditoria para outra pessoa/sprint.

---

## Fase 4 — Cobertura de testes dos fluxos happy path

Cria widget tests (ou integração) para os fluxos críticos, se não existirem já:
- Onboarding completo
- Criar cliente + validação de duplicado
- Criar máquina + mudança de estado
- Criar reserva sem sobreposição, e com sobreposição rejeitada
- Registar recebimento e ver aparecer no dashboard
- Colaborador cria lead e **não vê o menu de custos**
- Dashboard renderiza sem exceção em estado vazio e estado povoado
- Registo com convite válido → pedido criado com `origem='convite'`

**Coverage-alvo:** todos os widgets do happy path têm pelo menos 1 teste que os monta e verifica que não lançam. Não é 100% de coverage — é confiança no fluxo essencial.

---

## Fase 5 — RLS smoke test

**Não** é auditoria completa (fica para sprint separado). É sanity check:

- Escreve um teste (Dart ou SQL) que:
  1. Cria empresa A com utilizador `alice@a.pt`
  2. Cria empresa B com utilizador `bruno@b.pt`
  3. Alice cria uma máquina.
  4. Bruno autenticado consulta `punho_maquinas` — **não deve ver a máquina da Alice**.
- Falha no teste = P0 imediato, para tudo e reporta.

---

## Fase 6 — Documentação

Ao terminar:

1. `docs/AUDITORIA_BUGS_v0.0.3.md` — lista completa com estado FIXED/PENDING/P2, sem apagar entradas.
2. `docs/BACKLOG_v0.0.4.md` — se durante o bug hunt encontraste ideias de features novas, regista lá **sem implementar nada**.
3. Actualizar `docs/ESTADO_ATUAL_DA_APP.md` — o que passa de "modo demo" para "utilizável com dados reais" (só se justificado por testes e correcções feitas). Se nada mudou de estado, dizer no doc que o sprint foi estabilização sem alteração de âmbito de "utilização real".
4. Actualizar `docs/LIMITACOES_CONHECIDAS.md` — remover limitações que já não se aplicam; adicionar novas se descobriste.

---

## Gate de verificação (obrigatório)

1. `flutter test` — toda a suite verde, zero regressões. Reporta o número (antes vs depois).
2. `flutter analyze` — limpo.
3. `docs/AUDITORIA_BUGS_v0.0.3.md` — nenhuma entrada P0 ou P1 em estado PENDING.
4. **Smoke manual** — segue os 9 fluxos happy path em `flutter run -d windows` e confirma que corrres do princípio ao fim de cada um sem erro visível. Regista no doc: "smoke manual PASSA em `<data>` `<build>`".
5. Escreve `pubspec.yaml` **como está** — versão fica em `0.0.2+2`. Só bumpar quando o Cesar disser (é ele que decide quando é v0.0.3 na versão publicada).

## Entrega

- Branch `chore/estabilizacao-v0.0.3` (ou nome equivalente)
- N commits locais, mensagens no formato `fix(punho): <descrição>` para bugs e `test(punho): <descrição>` para testes novos
- **Sem push** para remote
- `docs/AUDITORIA_BUGS_v0.0.3.md` como entregável principal — é o documento que o Cesar lê para saber onde estamos

## Fora do âmbito (não fazer)

- Features novas (por muito tentador que seja)
- Refactorings grandes que não sejam necessários para fixar bug específico
- Alterar UI/UX por gosto — só se estiver na categoria P1 (ex: botão que não faz nada). Cosméticos ficam para v0.0.4.
- Auditoria completa de RLS (só o smoke test da Fase 5)
- Publicar release ou bumpar versão
