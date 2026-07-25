import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../domain/models/workforce.dart';

class CollaboratorsPage extends ConsumerWidget {
  const CollaboratorsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(operationsProvider);
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
                  for (final c in s.collaborators)
                    Card(
                      child: ListTile(
                        title: Text(c.name),
                        subtitle: Text(
                          '${c.status.name} · custo mensal: ${monthlyCollaboratorCost(c) == null ? 'por apurar' : '${monthlyCollaboratorCost(c)! / 100} €'} · custo/hora: ${hourlyCollaboratorCost(c)?.toStringAsFixed(2) ?? 'por apurar'}',
                        ),
                        trailing: const Text(
                          'Resultado atribuível\nnão é lucro contabilístico',
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

Future<void> _collaboratorDialog(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController();
  final cost = TextEditingController();
  final hours = TextEditingController(text: '40');
  final phone = TextEditingController();
  final role = TextEditingController();
  var frequency = CostFrequency.monthly;
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Novo colaborador'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
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
            onChanged: (value) => frequency = value!,
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
      actions: [
        FilledButton(
          onPressed: () {
            try {
              ref
                  .read(operationsProvider.notifier)
                  .saveCollaborator(
                    Collaborator(
                      id: 'co${DateTime.now().microsecondsSinceEpoch}',
                      name: name.text,
                      status: CollaboratorStatus.active,
                      phone: phone.text.trim().isEmpty
                          ? null
                          : phone.text.trim(),
                      role: role.text.trim().isEmpty ? null : role.text.trim(),
                      costFrequency: frequency,
                      costCents:
                          ((double.tryParse(cost.text.replaceAll(',', '.')) ??
                                      0) *
                                  100)
                              .round(),
                      schedule: _scheduleFromWeeklyHours(
                        int.tryParse(hours.text.trim()) ?? 0,
                      ),
                    ),
                  );
              Navigator.pop(context);
            } on StateError catch (e) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(e.message.toString())));
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
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

Future<void> _vehicleDialog(BuildContext context, WidgetRef ref) async {
  final plate = TextEditingController();
  final type = TextEditingController();
  final alias = TextEditingController();
  final monthlyPayment = TextEditingController();
  final insurance = TextEditingController();
  var insuranceFrequency = InsuranceFrequency.annual;
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Novo veículo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: plate,
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
            onChanged: (value) => insuranceFrequency = value!,
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () {
            ref
                .read(operationsProvider.notifier)
                .saveVehicle(
                  Vehicle(
                    id: 'v${DateTime.now().microsecondsSinceEpoch}',
                    plate: plate.text,
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
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}

int? _cents(String value) {
  if (value.trim().isEmpty) return null;
  final parsed = double.tryParse(value.replaceAll(',', '.'));
  return parsed == null || parsed < 0 ? null : (parsed * 100).round();
}
