# Plano: Fatia 1 (bug do formulário de lead) e Fatia 2 (reunião com alarme)
9/10/2026. Só planeamento. [F] facto lido · [I] inferência · [NL] não lido. Estimativas de horas são do agente, sem medição.
Decisão de origem: council `council-2026-10-09-crm-no-punho.md` + memória `project_punho-crm-lembretes-por-aparelho`.

## FATIA 1 — formulário de lead (≈2 h)
- Bug [F]: `_FormularioDeLeadState.aoGuardar` (lib/features/operations/presentation/operational_pages.dart:2486-2501) só chama `addLead` se nome e telemóvel não estiverem vazios, mas o `Navigator.pop` (:2500) está fora do `if`: fecha sempre, sem gravar nem avisar. Sem `trim()` («   » passa).
- O formulário do colaborador (collaborator_shell.dart ~190-215) NÃO tem o defeito: já faz trim, mostra «A lead precisa do nome e do telemóvel.» via `EcraDeFormulario(aviso: erro)` e retorna.
- Correcção (~15 linhas): `String? erro;` + `aviso: erro` (:2467); trim; se vazio → `setState(erro)` e `return`; só então gravar e fechar. Extrair `validarLead(nome, telemovel)` partilhada pelos dois formulários (10 min). Limpar o erro ao escrever (opcional).
- Testes (padrão test/features/operations/dialogos_formulario_test.dart:279-340): T1 nome vazio → erro e não fecha (correr ANTES da correcção: tem de falhar); T2 telemóvel vazio; T3 espaços; T4 preenchido grava (+ asserção no estado); T5 par equivalente para o colaborador.
- Na mesma passagem: verificar [NL] se o formulário de cliente (:2247-2428) tem o mesmo padrão e corrigir igual.
- NÃO entra: edição de lead, estados do pipeline, origem obrigatória, motivo de perda, email na lead, conversão, nada de CRM.

## FATIA 2 — reunião com alarme (≈36-40 h)
### Modelo
- `enum BookingTipo { maquina, reuniao }`, `tipo` (omissão `maquina`), `lembreteMinutos`, `criadoPorUid` em Booking (operations.dart:289-332).
- Armadilha [F]: 3 sítios reconstroem o Booking campo a campo e perderiam o tipo: `addBooking` (operations_controller.dart:942-960), `remarcarPara` (:1023-1035), `copyWith` (operations.dart:305-322). Teste: reunião remarcada continua reunião.
- Serialização: `_bookingToJson`/`_bookingFromJson` (operation_repository.dart:1063/1078); ler tipo tolerante (desconhecido → maquina). Reservas antigas → maquina.
- App antiga que receba uma reunião trata-a como reserva de máquina → lançar com versão mínima (todos os aparelhos actualizados).
- Projecção: `dados jsonb` guarda tudo; sem migration para armazenar.
### Servidor (precisa de ok do César: DB viva; testar primeiro em ramo)
- Criar reunião: colaborador já pode (`punho_colaborador_pode_criar('booking')`).
- Editar: hoje o colaborador só altera status/notes/responsável da reserva; remarcar, trocar cliente ou mudar lembrete seriam recusados (42501). Migration no gatilho `punho_operacoes_campos_do_colaborador`: se booking tipo reuniao (antes e depois) e `criadoPorUid = auth.uid()`, permitir startsAt/endsAt/customerId/snapshot/lembreteMinutos/notes/status; `tipo` imutável.
- Autor: `por_utilizador` é do último a escrever; por isso o gatilho de carimbo força `criadoPorUid` no payload (1.ª operação da entidade); o cliente lê-o. Cuidado com a ordem dos gatilhos before-insert e com apps antigas.
- Dono = utilizador igual aos outros (tem o seu auth.uid()).
### Consumidores (reunião NÃO é reserva de máquina)
- Recomendação: `OperationsState.bookings` passa a conter só reservas de máquina; lista nova `reunioes`; filtrar na origem (`_bookingsComORelogio` :285-294, `_fromRepo` :296-310). O repositório e a fila continuam a guardar tudo.
- Adaptar: relógio da reserva (relogio_da_reserva.dart:22-34, não pode passar a «Em aluguer»); método próprio `agendarReuniao` (addBooking tem mínimo de 12 h, exige máquina e liga `lead.bookingId` à reunião: corrompe a conversão); `remarcarReuniao` (muda a hora).
- Ignorar (verificar cada um com a fixture): tarefa «reserva sem valor» (tarefas_service.dart:333-350, :368), proximo_passo.dart (:131, :237) e minha_semana_page.dart:313, kpis.dart (~15 pontos: :347, :425, :571, :607, :633, :716, :768, :824, :893, :938, :984, :1061, :1593, :1638), kpis_da_cadeia, kpis_de_saude, atencao, break_even, maquina_parada, dinheiro_por_mexer, guidance_engine, conflito de máquina (explícito), recebimentos/fecho, collaborator_shell :238/:257.
- Teste decisivo: um estado com UMA reunião e nada mais → zero tarefas, zero passos, KPIs como antes, zero conflitos; e a inversa (reservas de máquina continuam a contar).
### UI
- Botão «Nova reunião» ao lado da nova marcação (BookingsPage, operational_pages.dart:2515; formulário em ecrã completo). Campos: cliente, dia, hora, «Avisar-me antes» (10/15/30 min/sem aviso; omissão = última usada, preferência local), notas. Duração fixa 60 min escondida.
- Calendário: chip distinto (ícone + «Reunião · cliente · hora»); mostrar sempre (não depende do filtro de máquina). Editar/cancelar tocando. Colaborador: «Nova reunião» nas acções rápidas [verificar se tem acesso ao calendário].
### Alarme
- Estado [F]: sem pacote de notificações; AGP 8.7.3; Flutter 3.44.8; sem desugaring; iOS fora (confirmado); a app corre também em Windows.
- Pacote: flutter_local_notifications + timezone + flutter_timezone (`zonedSchedule`, exactAllowWhileIdle); desugaring + receivers no manifest (confirmar na versão instalada).
- Permissões: POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM (pedido guiado, só na 1.ª reunião com lembrete), RECEIVE_BOOT_COMPLETED.
- Arquitectura: `lib/core/lembretes/` com interface `AgendadorDeLembretes`, `AgendadorLocal`, `AgendadorFalso` e função pura `reconciliar(reunioes, uidActual, agora) → plano`. Reconciliação completa após cada sync/escrita. Só agenda se tipo=reuniao, não cancelada, `criadoPorUid == uid actual`, lembrete definido, instante futuro. Janela 30 dias, máx. 50. Logout/troca de conta → cancelar tudo.
- Fuso/Verão: hora de parede local; testar à volta de 25-26/10/2026. Risco pré-existente [I]: a projecção pode deslocar `inicio` 1-2 h na leitura SQL (não afecta o alarme).
- Só toca depois de o aparelho sincronizar (dizê-lo na UI).
- MIUI/Redmi: maior risco do produto. Mitigações: pedir «Sem restrições» na bateria, «Arranque automático», bloquear nas recentes, ecrã de ajuda e botão «Testar alarme (daqui a 1 min)». Protótipo de 1 h ANTES de construir o resto.
- Windows: sem alarme agendado [I]; agendador no-op fora de Android.
### RGPD
- O nome do cliente da reunião está coberto pelo apagamento (customerNameSnapshot). NÃO está coberto: `notes` da reserva (texto livre) → acrescentar à redacção e a docs/RGPD.md.
- Notificação no ecrã bloqueado: sem notas nem NIF.
### Ordem e esforço (estimativas do agente)
0 Fatia 1: 2 h · 1 modelo+retrocompat: 3 h · 2 estado separado + relógio + fixture: 4 h · 3 controller: 3 h · 4 UI: 6 h · 5 servidor (ok do César): 4 h · 6 agendador: 8 h · 7 permissões + ajuda MIUI + testar alarme: 3 h · 8 prova real no Redmi (livre): 3-4 h · 9 RGPD notas (ok do César): 2 h.
### Fora de âmbito
Repetição, convidados, avisar outros utilizadores, calendário do telemóvel, push do servidor, iOS, soneca, alarmes para reservas de máquina, lembrete na ficha do cliente (revogado), CRM completo.

## Perguntas para o César (com recomendação)
1. Gestor em tablet Android ou PC Windows? (Windows: sem alarme.) 2. Antecedência por reunião (rec.). 3. Nome do cliente no ecrã bloqueado? (rec.: «Reunião às 10:30 com <nome>», sem notas). 4. SCHEDULE_EXACT_ALARM (rec.). 5. Ok a migrations em DB viva (primeiro em ramo). 6. Gestor pode editar a reunião do colaborador; o alarme fica do autor (rec.: sim). 7. Duração 60 min fixa (rec.). 8. Reunião passada fica esbatida no calendário (rec.). 9. Protótipo do alarme no Redmi antes de construir (rec.: sim). 10. Versão mínima obrigatória antes de lançar (rec.: sim).

## Primeiro passo de segunda-feira
Escrever T1 e vê-lo FALHAR; corrigir operational_pages.dart:2486-2501; T1-T4 verdes e `flutter analyze` limpo; depois o protótipo de alarme no Redmi quando estiver livre.
