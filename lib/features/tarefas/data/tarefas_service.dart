import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/guidance/guidance_engine.dart';
import '../../../core/operations/kpis.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../domain/models/workforce.dart';
import '../../auth/acesso_providers.dart';
import '../../auth/data/acesso_service.dart';
import '../../dashboard/recomendacao_providers.dart';
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
}) {
  final tarefas = <Tarefa>[];

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

  // 3. Máquinas criadas a partir do total declarado e ainda por baptizar.
  // Conta placeholders e não o delta `declaradas − registadas`: com os
  // placeholders o delta é zero mesmo havendo vinte linhas "Máquina 7".
  final porIdentificar = state.placeholdersDeMaquinas;
  if (porIdentificar > 0) {
    tarefas.add(
      Tarefa(
        id: 'maquinas-por-identificar',
        severidade: SeveridadeTarefa.aCompletar,
        titulo: porIdentificar == 1
            ? '1 máquina por identificar'
            : '$porIdentificar máquinas por identificar',
        subtitulo: 'Dá-lhes nome, referência e foto quando puderes',
        cta: 'Abrir Máquinas',
        destino: DestinoTarefa.maquinas,
      ),
    );
  } else if (state.hasUnidentifiedDeclaredMachines) {
    // Instalações anteriores aos placeholders: só têm o contador.
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

  // 5. Frota declarada e sem veículos registados.
  if (state.hasFleet && state.vehicles.where((v) => !v.archived).isEmpty) {
    tarefas.add(
      const Tarefa(
        id: 'frota-sem-veiculos',
        severidade: SeveridadeTarefa.aCompletar,
        titulo: 'Registar os veículos da frota',
        subtitulo: 'Declarou frota mas não há veículos identificados',
        cta: 'Abrir Frota',
        destino: DestinoTarefa.frota,
      ),
    );
  }

  // 6. Convites emitidos e ainda sem resposta. A lista chega de fora (é
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

  // 7. Recomendações adiadas que já voltaram a estar dentro do prazo ficam no
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
  return tarefasPendentes(
    state,
    DateTime.now(),
    recomendacoesAdiadas: adiadas,
    convites: convites,
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
