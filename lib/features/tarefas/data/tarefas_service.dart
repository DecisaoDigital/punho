import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/guidance/guidance_engine.dart';
import '../../../core/operations/kpis.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../domain/models/workforce.dart';
import '../../auth/acesso_providers.dart';
import '../../auth/data/acesso_service.dart';
import '../../dashboard/recomendacao_providers.dart';
import '../../leads/leads_entrada_providers.dart';
import '../domain/tarefa.dart';

/// Dias de atraso a partir dos quais uma cobrança passa a urgente.
const diasParaCobrancaUrgente = 15;

/// Um convite que expira dentro deste prazo passa a urgente: perdido o prazo, o
/// gestor tem de emitir outro e o convidado leva outra volta.
const horasParaConviteUrgente = 48;

/// Junta as pendências que estavam dispersas em alertas do painel.
///
/// É função pura sobre o estado para poder ser testada com datas fixas — o
/// `now` entra de fora.
List<Tarefa> tarefasPendentes(
  OperationsState state,
  DateTime now, {
  Map<String, DateTime> recomendacoesAdiadas = const {},
  List<Convite> convites = const [],
  int leadsRetidas = 0,
}) {
  final tarefas = <Tarefa>[];

  // 0. Leads que chegaram de fora e o servidor não conseguiu aceitar sozinho —
  // faltava o nome, o telefone não era reconhecível, ou o mesmo número já tinha
  // entrado. Ficam à espera de um toque. Uma lead parada é procura já paga que
  // ainda não foi trabalhada, por isso vem à frente de tudo o resto.
  if (leadsRetidas > 0) {
    tarefas.add(
      Tarefa(
        id: 'leads-retidas',
        severidade: SeveridadeTarefa.urgente,
        titulo: leadsRetidas == 1
            ? '1 lead à espera de triagem'
            : '$leadsRetidas leads à espera de triagem',
        subtitulo: 'Chegaram de fora e precisam de confirmação',
        cta: 'Ver leads',
        destino: DestinoTarefa.clientes,
      ),
    );
  }

  // 1. Cobranças com atraso — dinheiro que já era da empresa.
  for (final cobranca in cobrancasPorReceber(
    state,
    now,
    minimoDiasAtraso: diasParaCobrancaUrgente,
  )) {
    tarefas.add(
      Tarefa(
        id: 'cobranca-${cobranca.booking.id}',
        severidade: SeveridadeTarefa.urgente,
        titulo: 'Cobrar ${cobranca.clienteNome}',
        subtitulo:
            '${_euros(cobranca.emDividaCents)} em atraso há '
            '${cobranca.diasDeAtraso} dias',
        cta: 'Ver cliente',
        destino: DestinoTarefa.clientes,
      ),
    );
  }

  // 2. Dados por completar. O NIF é fiscal, portanto urgente; o resto não.
  for (final pendente in state.initialDataTasks) {
    final fiscal = pendente.contains('NIF');
    tarefas.add(
      Tarefa(
        id: 'dados-${pendente.hashCode}',
        severidade: fiscal
            ? SeveridadeTarefa.urgente
            : SeveridadeTarefa.aCompletar,
        titulo: pendente,
        subtitulo: fiscal
            ? 'Sem NIF não há factura em condições'
            : 'O Punho decide melhor com este dado preenchido',
        cta: 'Preencher',
        destino: DestinoTarefa.definicoesEmpresa,
      ),
    );
  }

  // 2-b. Fichas de colaborador sem o dado que o vínculo exige.
  //
  // Uma linha por pessoa, e não uma linha agregada: quem tem de agir precisa de
  // saber de quem se trata, e o nome é o que o gestor reconhece. Sem NISS não se
  // declara um contrato; sem NIF não se lança a despesa de um prestador.
  for (final colaborador in state.collaborators.where((c) => !c.archived)) {
    final semNiss =
        colaborador.employmentType == EmploymentType.contrato &&
        (colaborador.socialSecurityNumber ?? '').trim().isEmpty;
    final semNif =
        colaborador.employmentType == EmploymentType.recibosVerdes &&
        (colaborador.taxId ?? '').trim().isEmpty;
    if (!semNiss && !semNif) continue;
    tarefas.add(
      Tarefa(
        id: 'ficha-${colaborador.id}',
        severidade: SeveridadeTarefa.aCompletar,
        titulo: semNiss
            ? '${colaborador.name} — NISS em falta'
            : '${colaborador.name} — NIF em falta',
        subtitulo: semNiss
            ? 'Sem o NISS não se declara o contrato'
            : 'Sem o NIF não se lança a despesa do prestador',
        cta: 'Abrir ficha',
        destino: DestinoTarefa.colaboradores,
      ),
    );
  }

  // 3. Máquinas que faltam registar face ao total declarado no onboarding.
  // O onboarding não cria nenhuma — só aponta o caminho, contando o que falta
  // contra o que o gestor declarou.
  if (state.hasUnidentifiedDeclaredMachines) {
    tarefas.add(
      Tarefa(
        id: 'maquinas-por-identificar',
        severidade: SeveridadeTarefa.aCompletar,
        titulo: 'Identificar ${state.machinesStillToIdentify} máquinas',
        subtitulo:
            'Declarou ${state.totalMachinesDeclared} e estão registadas '
            '${state.registeredMachinesCount}',
        cta: 'Abrir Máquinas',
        destino: DestinoTarefa.maquinas,
      ),
    );
  }

  // 4. Colaboradores sem custo ou sem horário — sem isto o custo/hora não sai.
  final incompletos = state.collaborators
      .where(
        (c) =>
            !c.archived &&
            c.status == CollaboratorStatus.active &&
            (monthlyCollaboratorCost(c) == null ||
                hourlyCollaboratorCost(c) == null),
      )
      .toList();
  if (incompletos.isNotEmpty) {
    tarefas.add(
      Tarefa(
        id: 'colaboradores-incompletos',
        severidade: SeveridadeTarefa.aCompletar,
        titulo: incompletos.length == 1
            ? 'Completar a ficha de ${incompletos.single.name}'
            : 'Completar ${incompletos.length} fichas de colaborador',
        subtitulo: 'Falta custo ou horário — sem isso não há custo por hora',
        cta: 'Abrir Funcionários',
        destino: DestinoTarefa.colaboradores,
      ),
    );
  }

  // 5. Colaboradores declarados no onboarding e nenhum registado — o número
  // que o gestor deu no onboarding não cria ninguém, e sem esta tarefa
  // desaparecia sem deixar rasto. Mesma ideia das máquinas e da frota
  // (decisão de 2026-08-02): nada de fichas a fingir de pessoa — uma ficha
  // de colaborador carrega NIF/NISS e tipo de vínculo, e uma linha em branco
  // é risco fiscal, não ajuda.
  if (state.declaredCollaboratorCount > 0 &&
      state.collaborators.where((c) => !c.archived).isEmpty) {
    tarefas.add(
      Tarefa(
        id: 'colaboradores-por-registar',
        severidade: SeveridadeTarefa.aCompletar,
        titulo: state.declaredCollaboratorCount == 1
            ? '1 colaborador por registar'
            : '${state.declaredCollaboratorCount} colaboradores por registar',
        subtitulo: 'Declarou equipa no onboarding mas não há ninguém registado',
        cta: 'Abrir Funcionários',
        destino: DestinoTarefa.colaboradores,
      ),
    );
  }

  // 6. Veículos que faltam registar face ao total declarado no onboarding.
  // Mesma ideia das máquinas: o onboarding não cria nenhum, só conta o que
  // falta contra o que o gestor declarou.
  if (state.hasUnidentifiedDeclaredVehicles) {
    tarefas.add(
      Tarefa(
        id: 'frota-sem-veiculos',
        severidade: SeveridadeTarefa.aCompletar,
        titulo: 'Identificar ${state.vehiclesStillToIdentify} veículos',
        subtitulo:
            'Declarou ${state.declaredVehicleCount} e estão registados '
            '${state.registeredVehiclesCount}',
        cta: 'Abrir Frota',
        destino: DestinoTarefa.frota,
      ),
    );
  }

  // 7. Convites emitidos e ainda sem resposta. A lista chega de fora (é
  // assíncrona e só existe com Supabase ligado); em modo de demonstração vem
  // vazia e esta fonte simplesmente não contribui.
  for (final convite in convites.where((c) => c.disponivelEm(now))) {
    final horas = convite.expiraEm.difference(now).inHours;
    final aExpirar = horas <= horasParaConviteUrgente;
    tarefas.add(
      Tarefa(
        id: 'convite-${convite.codigo}',
        severidade: aExpirar
            ? SeveridadeTarefa.urgente
            : SeveridadeTarefa.aCompletar,
        titulo: 'Convite sem resposta: ${convite.email}',
        subtitulo: aExpirar
            ? 'Expira em ${horas <= 1 ? 'menos de uma hora' : '$horas horas'} — '
                  'depois disso é preciso emitir outro'
            : '${convite.perfil == 'gestor' ? 'Gestor' : 'Colaborador'} · '
                  'válido até ${_data(convite.expiraEm)}',
        cta: 'Abrir convite',
        destino: DestinoTarefa.convites,
        referencia: convite.codigo,
      ),
    );
  }

  // 8. Recomendações adiadas que já voltaram a estar dentro do prazo ficam no
  // painel; as que ainda estão adiadas aparecem aqui, para não se perderem.
  final todas = GuidanceEngine().evaluate(
    GuidanceInput(
      bookings: state.bookings,
      machines: state.machines,
      receipts: state.receipts,
      expenses: state.expenses,
      now: now,
    ),
  );
  for (final recomendacao in todas) {
    final ate = recomendacoesAdiadas[recomendacao.id];
    if (ate == null || !now.isBefore(ate)) continue;
    tarefas.add(
      Tarefa(
        id: 'recomendacao-${recomendacao.id}',
        severidade: SeveridadeTarefa.sugestao,
        titulo: recomendacao.title,
        subtitulo: 'Adiada — volta a ${_data(ate)}',
        cta: 'Ver no painel',
        destino: DestinoTarefa.painel,
      ),
    );
  }

  tarefas.sort(
    (a, b) => b.severidade.prioridade.compareTo(a.severidade.prioridade),
  );
  return tarefas;
}

String _euros(int cents) =>
    '${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')} €';

String _data(DateTime data) =>
    '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}';

/// Tarefas pendentes vistas pela UI. Reavalia sempre que o estado muda.
final tarefasProvider = Provider<List<Tarefa>>((ref) {
  final state = ref.watch(operationsProvider);
  final adiadas = ref.watch(recomendacoesAdiadasProvider);
  // `valueOrNull` de propósito: sem Supabase o provider dos convites fica em
  // erro (não há `Supabase.instance`) e a lista de tarefas não pode rebentar
  // por causa disso — nem mostrar erro de rede a quem está em demonstração.
  final convites = ref.watch(convitesProvider).valueOrNull ?? const <Convite>[];
  // Observar aqui é também o que faz a caixa de entrada ser puxada: o provider
  // vai buscar as leads novas ao construir-se, e as aceites entram sozinhas no
  // pipeline. As Tarefas são o primeiro sítio da app que precisa de as saber.
  final retidas = ref.watch(leadsRetidasProvider).length;
  return tarefasPendentes(
    state,
    DateTime.now(),
    recomendacoesAdiadas: adiadas,
    convites: convites,
    leadsRetidas: retidas,
  );
});

/// Contagem para o badge da barra lateral.
final contagemTarefasPendentesProvider = Provider<int>(
  (ref) => ref.watch(tarefasProvider).length,
);

/// O badge fica vermelho só quando há mesmo algo urgente. Um badge vermelho
/// permanente por causa de uma morada em falta deixa de significar nada.
final tarefasTemUrgenteProvider = Provider<bool>(
  (ref) => ref
      .watch(tarefasProvider)
      .any((t) => t.severidade == SeveridadeTarefa.urgente),
);
