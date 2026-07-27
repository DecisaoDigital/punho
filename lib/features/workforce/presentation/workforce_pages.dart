import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/layout/dialogo_de_formulario.dart';
import '../../../core/operations/kpis.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../domain/models/workforce.dart';

class CollaboratorsPage extends ConsumerWidget {
  const CollaboratorsPage({super.key, this.agora});

  /// Injectável para os testes fixarem o mês das vendas.
  final DateTime? agora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(operationsProvider);
    final mes = agora ?? DateTime.now();
    // Arquivados fora da lista: eliminar tem de fazer a linha desaparecer, ou
    // não se acredita que tenha eliminado.
    final colaboradores = s.collaborators.where((c) => !c.archived).toList();
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Funcionários',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              '${s.activeCollaborators} colaboradores ativos de ${s.activeCollaboratorLimit} vagas contratadas',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _collaboratorDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar colaborador'),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final c in colaboradores)
                    Card(
                      child: ListTile(
                        // Tocar na linha edita: era o gesto que o Cesar tentou
                        // primeiro e não fazia nada.
                        onTap: () => _collaboratorDialog(context, ref, c),
                        title: Text(c.name),
                        subtitle: Text(_subtitulo(c, s, mes)),
                        trailing: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Editar colaborador',
                              onPressed: () =>
                                  _collaboratorDialog(context, ref, c),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Eliminar colaborador',
                              onPressed: () =>
                                  _confirmarEliminarColaborador(context, ref, c),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custo, custo/hora e o que este colaborador trouxe para dentro no mês.
///
/// As vendas vêm à frente do custo de propósito: um número de custo sozinho lê-se
/// como despesa e mais nada.
String _subtitulo(Collaborator c, OperationsState s, DateTime mes) {
  final vendas = vendasDoMesDoColaborador(s, c.id, mes);
  final custoMensal = monthlyCollaboratorCost(c);
  final valor = vendas.valorCents;
  final vendasTexto = switch (vendas) {
    (contagem: 0, valorCents: _) => 'sem reservas este mês',
    (contagem: final n, valorCents: null) =>
      '$n ${n == 1 ? 'reserva' : 'reservas'} este mês · valor por apurar',
    (contagem: final n, valorCents: _) =>
      '$n ${n == 1 ? 'reserva' : 'reservas'} este mês · ${(valor! / 100).toStringAsFixed(2)} €',
  };
  // O custo/hora vem em cêntimos, como o mensal. Estava a ser mostrado tal e
  // qual: um colaborador a 14,10 €/hora aparecia como "custo/hora: 1410.26".
  final custoHora = hourlyCollaboratorCost(c);
  return '$vendasTexto\n'
      '${_estadoEmPortugues(c.status)} · custo mensal: '
      '${custoMensal == null ? 'por apurar' : '${(custoMensal / 100).toStringAsFixed(2)} €'}'
      ' · custo/hora: '
      '${custoHora == null ? 'por apurar' : '${(custoHora / 100).toStringAsFixed(2)} €'}';
}

/// O `status.name` era o nome do valor do enum: a lista dizia "active".
String _estadoEmPortugues(CollaboratorStatus status) => switch (status) {
  CollaboratorStatus.active => 'Ativo',
  CollaboratorStatus.inactive => 'Inativo',
};

/// Eliminar com 6 segundos para anular, como nas máquinas.
Future<void> _confirmarEliminarColaborador(
  BuildContext context,
  WidgetRef ref,
  Collaborator c,
) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Eliminar ${c.name}?'),
      content: const Text(
        'A ficha sai da lista. As reservas de que este colaborador foi '
        'responsável não se perdem.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  if (confirmado != true || !context.mounted) return;
  ref.read(operationsProvider.notifier).archiveCollaborator(c.id);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('${c.name} eliminado.'),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: 'Anular',
        onPressed: () =>
            ref.read(operationsProvider.notifier).unarchiveCollaborator(c.id),
      ),
    ),
  );
}

Future<void> _collaboratorDialog(
  BuildContext context,
  WidgetRef ref, [
  Collaborator? current,
]) => showDialog(
  context: context,
  // Não fecha ao tocar fora — evita perder texto por engano. Só é honesto
  // porque agora há um Cancelar: até aqui o diálogo não tinha saída nenhuma a
  // não ser gravar.
  barrierDismissible: false,
  builder: (_) => _FormularioDeColaborador(
    notifier: ref.read(operationsProvider.notifier),
    current: current,
  ),
);

class _FormularioDeColaborador extends StatefulWidget {
  const _FormularioDeColaborador({required this.notifier, this.current});

  final OperationsController notifier;
  final Collaborator? current;

  @override
  State<_FormularioDeColaborador> createState() =>
      _FormularioDeColaboradorState();
}

class _FormularioDeColaboradorState extends State<_FormularioDeColaborador> {
  late final Collaborator? current = widget.current;
  late final name = TextEditingController(text: current?.name);
  late final cost = TextEditingController(
    text: current?.costCents == null
        ? ''
        : (current!.costCents! / 100).toStringAsFixed(2),
  );
  late final hours = TextEditingController(
    text: '${_weeklyHoursFromSchedule(current?.schedule) ?? 40}',
  );
  late final phone = TextEditingController(text: current?.phone);
  late final role = TextEditingController(text: current?.role);
  late var frequency = current?.costFrequency ?? CostFrequency.monthly;

  @override
  void dispose() {
    name.dispose();
    cost.dispose();
    hours.dispose();
    phone.dispose();
    role.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DialogoDeFormulario(
      // "Adicionar" em vez de "Novo": deixa claro que é acção pendente, não
      // confirmação de que já foi criado.
      titulo: current == null
          ? 'Adicionar colaborador'
          : 'Editar colaborador',
      corpo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          TextField(
            controller: cost,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Custo estimado para a empresa (€)',
            ),
          ),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Telemóvel'),
          ),
          TextField(
            controller: role,
            decoration: const InputDecoration(labelText: 'Função'),
          ),
          DropdownButtonFormField<CostFrequency>(
            value: frequency,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Periodicidade do custo',
            ),
            items: const [
              DropdownMenuItem(
                value: CostFrequency.monthly,
                child: Text('Custo mensal'),
              ),
              DropdownMenuItem(
                value: CostFrequency.weekly,
                child: Text('Custo semanal'),
              ),
            ],
            onChanged: (value) => setState(() => frequency = value!),
          ),
          TextField(
            controller: hours,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Horas semanais previstas',
              helperText: 'Usadas para calcular o custo/hora estimado.',
            ),
          ),
        ],
      ),
      aoGuardar: () {
        // Validação: nome é obrigatório. Sem isto, um tap por engano criava um
        // colaborador anónimo silenciosamente — o Cesar apanhou este bug no
        // smoke da v0.0.4.
        if (name.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Indica o nome do colaborador.')),
          );
          return;
        }
        final anterior = current;
        final custoCents =
            ((double.tryParse(cost.text.replaceAll(',', '.')) ?? 0) * 100)
                .round();
        final horario = _scheduleFromWeeklyHours(
          int.tryParse(hours.text.trim()) ?? 0,
        );
        try {
          // A editar mantém-se o mesmo id e passa-se por copyWith: construir um
          // Collaborator novo criava um segundo registo e deixava o antigo na
          // lista, além de perder as notas que este diálogo não mostra.
          widget.notifier.saveCollaborator(
            anterior != null
                ? anterior.copyWith(
                    name: name.text.trim(),
                    phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
                    role: role.text.trim().isEmpty ? null : role.text.trim(),
                    costFrequency: frequency,
                    costCents: custoCents,
                    schedule: horario,
                  )
                : Collaborator(
                    id: 'co${DateTime.now().microsecondsSinceEpoch}',
                    name: name.text.trim(),
                    status: CollaboratorStatus.active,
                    phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
                    role: role.text.trim().isEmpty ? null : role.text.trim(),
                    costFrequency: frequency,
                    costCents: custoCents,
                    schedule: horario,
                  ),
          );
          Navigator.pop(context);
        } on StateError catch (e) {
          // Excedeu as vagas contratadas: o diálogo fica aberto com o que
          // estava escrito.
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message.toString())));
        }
      },
    );
  }
}

/// O inverso do [_scheduleFromWeeklyHours], para o diálogo de edição mostrar as
/// horas que lá estavam em vez de voltar sempre a 40.
///
/// Devolve `null` quando o horário está vazio ou não foi gerado a partir de
/// horas semanais — nesse caso o campo assume o valor por omissão, e não um
/// número inventado a partir de um horário feito à mão.
int? _weeklyHoursFromSchedule(Map<int, WorkDay>? schedule) {
  if (schedule == null || schedule.isEmpty) return null;
  var minutos = 0;
  for (final dia in schedule.values) {
    final inicio = dia.start, fim = dia.end;
    if (!dia.works || inicio == null || fim == null) continue;
    minutos += fim.minutes - inicio.minutes;
  }
  return minutos <= 0 ? null : (minutos / 60).round();
}

Map<int, WorkDay> _scheduleFromWeeklyHours(int weeklyHours) {
  if (weeklyHours <= 0) return const {};
  final minutesPerDay = (weeklyHours * 60 / 5).round();
  final endMinutes = 9 * 60 + minutesPerDay;
  if (endMinutes > 24 * 60) return const {};
  return {
    for (var day = 1; day <= 5; day++)
      day: WorkDay(
        works: true,
        start: const TimeOfDay(9, 0),
        end: TimeOfDay(endMinutes ~/ 60, endMinutes % 60),
      ),
  };
}

class VehiclesPage extends ConsumerWidget {
  const VehiclesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(operationsProvider);
    final total = s.vehicles.fold(0, (sum, v) => sum + monthlyFleetCost(v));
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Veículos', style: Theme.of(context).textTheme.headlineMedium),
            Text(
              s.vehicles.isEmpty
                  ? 'Frota declarada, veículos por identificar'
                  : 'Custo mensal estimado da frota: ${(total / 100).toStringAsFixed(2)} €',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _vehicleDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar veículo'),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final v in s.vehicles)
                    Card(
                      child: ListTile(
                        title: Text(v.plate),
                        subtitle: Text(
                          '${v.type} · ${(monthlyFleetCost(v) / 100).toStringAsFixed(2)} €/mês',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _vehicleDialog(BuildContext context, WidgetRef ref) => showDialog(
  context: context,
  // Os mesmos quatro defeitos que o diálogo dos colaboradores tinha e que o
  // Cesar apanhou no smoke da v0.0.4: fechava ao tocar fora, o título dizia
  // "Novo" (leu-se como "já foi criado"), não validava nada e não punha o
  // cursor no primeiro campo.
  barrierDismissible: false,
  builder: (_) =>
      _FormularioDeVeiculo(notifier: ref.read(operationsProvider.notifier)),
);

class _FormularioDeVeiculo extends StatefulWidget {
  const _FormularioDeVeiculo({required this.notifier});

  final OperationsController notifier;

  @override
  State<_FormularioDeVeiculo> createState() => _FormularioDeVeiculoState();
}

class _FormularioDeVeiculoState extends State<_FormularioDeVeiculo> {
  final plate = TextEditingController();
  final type = TextEditingController();
  final alias = TextEditingController();
  final monthlyPayment = TextEditingController();
  final insurance = TextEditingController();
  var insuranceFrequency = InsuranceFrequency.annual;

  @override
  void dispose() {
    plate.dispose();
    type.dispose();
    alias.dispose();
    monthlyPayment.dispose();
    insurance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DialogoDeFormulario(
      titulo: 'Adicionar veículo',
      corpo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: plate,
            autofocus: true,
            // Matrículas escrevem-se em maiúsculas.
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Matrícula'),
          ),
          TextField(
            controller: type,
            decoration: const InputDecoration(labelText: 'Tipo'),
          ),
          TextField(
            controller: alias,
            decoration: const InputDecoration(
              labelText: 'Nome / identificação',
            ),
          ),
          TextField(
            controller: monthlyPayment,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Prestação mensal (€)',
            ),
          ),
          TextField(
            controller: insurance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Seguro (€)'),
          ),
          DropdownButtonFormField<InsuranceFrequency>(
            value: insuranceFrequency,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Periodicidade do seguro',
            ),
            items: const [
              DropdownMenuItem(
                value: InsuranceFrequency.monthly,
                child: Text('Mensal'),
              ),
              DropdownMenuItem(
                value: InsuranceFrequency.semiannual,
                child: Text('Semestral'),
              ),
              DropdownMenuItem(
                value: InsuranceFrequency.annual,
                child: Text('Anual'),
              ),
            ],
            onChanged: (value) => setState(() => insuranceFrequency = value!),
          ),
        ],
      ),
      aoGuardar: () {
        // Sem matrícula o veículo não se identifica. Não se valida o formato
        // AA-11-BB: pode ser matrícula estrangeira ou histórica.
        final matricula = plate.text.trim();
        if (matricula.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Indica a matrícula do veículo.')),
          );
          return;
        }
        widget.notifier.saveVehicle(
          Vehicle(
            id: 'v${DateTime.now().microsecondsSinceEpoch}',
            plate: matricula,
            type: type.text,
            status: VehicleStatus.active,
            alias: alias.text.trim().isEmpty ? null : alias.text.trim(),
            monthlyPaymentCents: _cents(monthlyPayment.text),
            insuranceCents: _cents(insurance.text),
            insuranceFrequency: insurance.text.trim().isEmpty
                ? null
                : insuranceFrequency,
          ),
        );
        Navigator.pop(context);
      },
    );
  }
}

int? _cents(String value) {
  if (value.trim().isEmpty) return null;
  final parsed = double.tryParse(value.replaceAll(',', '.'));
  return parsed == null || parsed < 0 ? null : (parsed * 100).round();
}
