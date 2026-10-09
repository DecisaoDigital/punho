# Execução autónoma do CRM (ordem do César, 9/10/2026)
Mandato: fazer por etapas até tudo implantado e testado no telemóvel; só chamar o César se não houver solução; ao fim, se correr bem, FAZER COMMIT. Firebase separado para o Punho. NÃO publicar release (só a pedido explícito, cada vez). Decisões: `DECISOES_CRM_2026-10-09.md`. Plano técnico: `PLANO_FATIAS_1_E_2.md`. Ramo git: `crm-fase1` (criado de main fac564e). Testes e builds no i9.

## Regras de execução
- Cada etapa: teste primeiro (ver falhar), código, `flutter analyze` + `flutter test` limpos, anotar aqui.
- Migrations: aditivas e retrocompatíveis (cuidado com 42501 em apps antigas); testar SQL dentro de transacção com ROLLBACK antes de aplicar; guardar o ficheiro em supabase/migrations.
- Redmi: já autorizado pelo César (9/10); instalar com `pm install -r -g`; não mexer em mais nada no telemóvel.
- Bloqueio conhecido: criar o projecto Firebase do Punho (sem CLI nem login no i9). Deixar para o fim; é o único pedido ao César.

## Etapas (marcar [x] com data e resultado)
- [x] E1 (9/10, commit no ramo, 1373 testes verdes) Fatia 1: bug do formulário de lead + validarLead partilhada + verificar formulário de cliente (testes T1-T5)
- [x] E2 (9/10) Protótipo no Redmi (M2101K6G, MIUI V14, Android 13): flutter_local_notifications 22.3.1 + timezone + flutter_timezone 5.1.1, desugaring + receivers no manifest, SCHEDULE_EXACT_ALARM=allow. RESULTADO: 3/3 alarmes (60/120/180 s) dispararam em segundo plano com o ecrã desligado, 2 rondas. NÃO verificado: «limpar das recentes» (swipe por adb não passa o ecrã de bloqueio) e reinício do telemóvel — verificar à mão/no fim. API do pacote: initialize(settings:), zonedSchedule(id:, title:, body:, scheduledDate:, notificationDetails:, androidScheduleMode:); FlutterTimezone.getLocalTimezone().identifier. Protótipo desinstalado; fonte em scratchpad/alarme_proto. Instalar APK novo no MIUI: método da memória feedback_miui-instalacao-usb-expira (pm install em 2.º plano + tap 540 1975 + tap 311 2102).
- [x] E3 Modelo da reunião: BookingTipo, lembreteMinutos, criadoPorUid; serialização e retrocompat; 3 reconstrutores
- [x] E4 Reuniões fora das reservas de máquina: state.reunioes, relógio, fixture «só uma reunião»
- [x] E5 Controller + UI da reunião (criar/editar/cancelar, calendário, antecedência)
- [x] E6 Agendador de alarmes (pacote, manifest, reconciliar, logout) + permissões + ajuda MIUI + «Testar alarme»
- [x] E7 (aplicada à DB viva 9/10; testada em transacção revertida, 8 casos) Servidor: permissões do colaborador para reuniões + carimbo do autor (migration testada com ROLLBACK)
- [x] E8 Leads: estado «qualificada», origem «prospecção própria», cliente existente (E.164) não vira lead, conversão ao fecho, operador responsável no cliente
- [x] E9 (policy aplicada à DB viva, testada em rollback) Atribuição: caixa «por atribuir», tarefa, lista «Para contactar hoje» do operador, visibilidade por atribuído (migration RLS)
- [x] E10 Categoria de máquina + tabela de preços por período (aguarda 2 respostas do César: períodos intermédios, máquina B) — usar recomendações se não responder: pacote mais barato que cubra; B = categoria à parte
- [x] E11 Push: camada 1 (app aberta) e camada 2 (FCM, Firebase punho-fist, edge function punho-push, segredo PUNHO_FCM_SERVICE_ACCOUNT_JSON). Provado no Redmi a 9/10: lead criada pelo operador por REST → «Lead nova» no ecrã bloqueado, app em segundo plano. Por provar: atribuição a operador num 2.º aparelho, app morta de vez.
- [x] E12 Prova no Redmi: alarme exacto dispara com ecrã bloqueado e com o processo morto (am kill); reboot e fluxo com dados reais por testar. Commit feito.
