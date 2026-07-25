import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/machine_image_store.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../domain/models/operations.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});
  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  int step = 0, collaborators = 0, machines = 0;
  bool fleet = false, insertMachines = false;
  String legal = 'Empresário em Nome Individual';
  final ownerName = TextEditingController();
  final name = TextEditingController();
  final taxId = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final address = TextEditingController();
  final postalCode = TextEditingController();
  final locality = TextEditingController();
  final revenueLastYear = TextEditingController();
  final revenueThisYear = TextEditingController();
  final maintenanceLastYear = TextEditingController();
  final fixedMonthlyCosts = TextEditingController();
  @override
  void dispose() {
    for (final controller in [
      name,
      ownerName,
      taxId,
      phone,
      email,
      address,
      postalCode,
      locality,
      revenueLastYear,
      revenueThisYear,
      maintenanceLastYear,
      fixedMonthlyCosts,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const titles = [
      'Como te chamas?',
      'Como se chama a empresa?',
      'Qual é a forma jurídica?',
      'Qual é o NIF da empresa?',
      'Como podemos contactar a empresa?',
      'Onde fica a empresa?',
      'Tem colaboradores?',
      'A empresa tem veículos?',
      'Quantas máquinas tem aproximadamente?',
      'Quanto faturou no ano passado?',
      'Quanto faturou este ano até hoje?',
      'Quanto gastou em manutenção no ano passado?',
      'Quais são os custos fixos mensais?',
      'Quer inserir as primeiras máquinas agora?',
    ];
    const helps = [
      'O Punho orienta a pessoa responsável por decidir e agir na empresa.',
      'Usamos este nome para personalizar o espaço de gestão.',
      'Ajuda a preparar os dados da empresa; pode ser alterado mais tarde.',
      'É importante para a identificação e faturação. Se não souber agora, ficará como tarefa aberta.',
      'Telemóvel e email ajudam a centralizar as futuras comunicações.',
      'Morada, código-postal e localidade. Não é pedido país.',
      'Mostramos Funcionários apenas quando fizer sentido para a equipa.',
      'Ativa a área de Veículos quando a empresa tiver frota.',
      'Uma estimativa é suficiente; não precisa de ser exata.',
      'Pode indicar um número redondo. Se não souber, avance: o Punho irá lembrar-lhe.',
      'Indique o acumulado deste ano até ao momento. Pode preencher mais tarde.',
      'Mesmo uma estimativa ajuda a perceber o peso real das avarias e revisões.',
      'Renda, eletricidade, água, seguros, programas e outros custos recorrentes. Uma estimativa chega.',
      'Pode adicionar máquinas agora ou a qualquer momento.',
    ];
    final input = switch (step) {
      0 => TextField(
        controller: ownerName,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Nome do empresário ou responsável',
          border: OutlineInputBorder(),
        ),
      ),
      1 => TextField(
        controller: name,
        decoration: const InputDecoration(
          labelText: 'Nome da empresa',
          border: OutlineInputBorder(),
        ),
      ),
      2 => DropdownButtonFormField<String>(
        value: legal,
        decoration: const InputDecoration(border: OutlineInputBorder()),
        items: const [
          DropdownMenuItem(
            value: 'Empresário em Nome Individual',
            child: Text('Empresário em Nome Individual'),
          ),
          DropdownMenuItem(value: 'Lda.', child: Text('Lda.')),
        ],
        onChanged: (v) => setState(() => legal = v!),
      ),
      3 => TextField(
        controller: taxId,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'NIF da empresa',
          border: OutlineInputBorder(),
        ),
      ),
      4 => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Telemóvel ou telefone',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      5 => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: address,
            decoration: const InputDecoration(
              labelText: 'Morada',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: postalCode,
            decoration: const InputDecoration(
              labelText: 'Código-postal',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: locality,
            decoration: const InputDecoration(
              labelText: 'Localidade',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      6 => _NumberChoice(
        label: 'Número aproximado de colaboradores',
        value: collaborators,
        onChanged: (v) => setState(() => collaborators = v),
      ),
      7 => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(fleet ? 'Sim, temos veículos' : 'Não, não temos veículos'),
        value: fleet,
        onChanged: (v) => setState(() => fleet = v),
      ),
      8 => _NumberChoice(
        label: 'Número aproximado de máquinas',
        value: machines,
        onChanged: (v) => setState(() => machines = v),
      ),
      9 => _EuroInput(
        controller: revenueLastYear,
        label: 'Faturação no ano passado (€)',
      ),
      10 => _EuroInput(
        controller: revenueThisYear,
        label: 'Faturação deste ano até hoje (€)',
      ),
      11 => _EuroInput(
        controller: maintenanceLastYear,
        label: 'Manutenção paga no ano passado (€)',
      ),
      12 => _EuroInput(
        controller: fixedMonthlyCosts,
        label: 'Custos fixos mensais (€)',
      ),
      _ => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Sim, inserir agora'),
        value: insertMachines,
        onChanged: (v) => setState(() => insertMachines = v),
      ),
    };
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Punho',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 28),
                Text('${step + 1} de ${titles.length}'),
                const SizedBox(height: 8),
                Text(
                  titles[step],
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(helps[step]),
                const SizedBox(height: 24),
                input,
                const SizedBox(height: 28),
                Row(
                  children: [
                    if (step > 0)
                      TextButton(
                        onPressed: () => setState(() => step--),
                        child: const Text('Voltar'),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        if (step < titles.length - 1) {
                          setState(() => step++);
                        } else {
                          ref
                              .read(operationsProvider.notifier)
                              .completeOnboarding(
                                ownerName: _optional(ownerName.text),
                                companyName: name.text.trim().isEmpty
                                    ? 'A minha empresa'
                                    : name.text.trim(),
                                legalForm: legal,
                                hasFleet: fleet,
                                collaborators: collaborators,
                                totalMachinesDeclared: machines,
                                insertMachinesNow: insertMachines,
                                companyTaxId: _optional(taxId.text),
                                companyPhone: _optional(phone.text),
                                companyEmail: _optional(email.text),
                                companyAddress: _optional(address.text),
                                companyPostalCode: _optional(postalCode.text),
                                companyLocality: _optional(locality.text),
                                revenueLastYearCents: _euroCents(
                                  revenueLastYear.text,
                                ),
                                revenueThisYearCents: _euroCents(
                                  revenueThisYear.text,
                                ),
                                maintenanceLastYearCents: _euroCents(
                                  maintenanceLastYear.text,
                                ),
                                fixedMonthlyCostsCents: _euroCents(
                                  fixedMonthlyCosts.text,
                                ),
                              );
                        }
                      },
                      child: Text(
                        step == titles.length - 1 ? 'Começar' : 'Continuar',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? _optional(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _euroCents(String value) {
  final raw = value.trim().replaceAll(' ', '');
  if (raw.isEmpty) return null;
  final normalized = raw.contains(',')
      ? raw.replaceAll('.', '').replaceAll(',', '.')
      : raw;
  final amount = double.tryParse(normalized);
  return amount == null || amount < 0 ? null : (amount * 100).round();
}

class _EuroInput extends StatelessWidget {
  const _EuroInput({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      hintText: 'Ex.: 35000',
      suffixText: '€',
      border: const OutlineInputBorder(),
    ),
  );
}

class _NumberChoice extends StatelessWidget {
  const _NumberChoice({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      IconButton(
        onPressed: value > 0 ? () => onChanged(value - 1) : null,
        icon: const Icon(Icons.remove_circle_outline),
      ),
      Text('$value'),
      IconButton(
        onPressed: () => onChanged(value + 1),
        icon: const Icon(Icons.add_circle_outline),
      ),
    ],
  );
}

class InitialDataTasksPage extends ConsumerStatefulWidget {
  const InitialDataTasksPage({super.key});

  @override
  ConsumerState<InitialDataTasksPage> createState() =>
      _InitialDataTasksPageState();
}

class _InitialDataTasksPageState extends ConsumerState<InitialDataTasksPage> {
  late final TextEditingController ownerName;
  late final TextEditingController taxId;
  late final TextEditingController phone;
  late final TextEditingController email;
  late final TextEditingController address;
  late final TextEditingController postalCode;
  late final TextEditingController locality;
  late final TextEditingController revenueLastYear;
  late final TextEditingController revenueThisYear;
  late final TextEditingController maintenanceLastYear;
  late final TextEditingController fixedMonthlyCosts;

  @override
  void initState() {
    super.initState();
    final data = ref.read(operationsProvider);
    ownerName = TextEditingController(text: data.ownerName ?? '');
    taxId = TextEditingController(text: data.companyTaxId ?? '');
    phone = TextEditingController(text: data.companyPhone ?? '');
    email = TextEditingController(text: data.companyEmail ?? '');
    address = TextEditingController(text: data.companyAddress ?? '');
    postalCode = TextEditingController(text: data.companyPostalCode ?? '');
    locality = TextEditingController(text: data.companyLocality ?? '');
    revenueLastYear = TextEditingController(
      text: _euros(data.revenueLastYearCents),
    );
    revenueThisYear = TextEditingController(
      text: _euros(data.revenueThisYearCents),
    );
    maintenanceLastYear = TextEditingController(
      text: _euros(data.maintenanceLastYearCents),
    );
    fixedMonthlyCosts = TextEditingController(
      text: _euros(data.fixedMonthlyCostsCents),
    );
  }

  @override
  void dispose() {
    for (final controller in [
      taxId,
      ownerName,
      phone,
      email,
      address,
      postalCode,
      locality,
      revenueLastYear,
      revenueThisYear,
      maintenanceLastYear,
      fixedMonthlyCosts,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(operationsProvider).initialDataTasks;
    return Scaffold(
      appBar: AppBar(title: const Text('Dados por completar')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Sem estes dados, o Punho não deve tirar conclusões definitivas. Pode preencher por etapas e guardar quando quiser.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (pending.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '${pending.length} tarefas abertas',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              for (final task in pending)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text('• $task'),
                ),
            ],
            const SizedBox(height: 24),
            Text(
              'Identificação da empresa',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ownerName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome do empresário ou responsável',
              ),
            ),
            TextField(
              controller: taxId,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'NIF da empresa'),
            ),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telemóvel ou telefone',
              ),
            ),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: address,
              decoration: const InputDecoration(labelText: 'Morada'),
            ),
            TextField(
              controller: postalCode,
              decoration: const InputDecoration(labelText: 'Código-postal'),
            ),
            TextField(
              controller: locality,
              decoration: const InputDecoration(labelText: 'Localidade'),
            ),
            const SizedBox(height: 24),
            Text(
              'Referências para orientar a gestão',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pode usar valores redondos. Não é uma declaração fiscal.',
            ),
            const SizedBox(height: 8),
            _EuroInput(
              controller: revenueLastYear,
              label: 'Faturação no ano passado (€)',
            ),
            _EuroInput(
              controller: revenueThisYear,
              label: 'Faturação deste ano até hoje (€)',
            ),
            _EuroInput(
              controller: maintenanceLastYear,
              label: 'Manutenção paga no ano passado (€)',
            ),
            _EuroInput(
              controller: fixedMonthlyCosts,
              label: 'Custos fixos mensais (€)',
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () {
                ref
                    .read(operationsProvider.notifier)
                    .updateInitialData(
                      ownerName: _optional(ownerName.text),
                      companyTaxId: _optional(taxId.text),
                      companyPhone: _optional(phone.text),
                      companyEmail: _optional(email.text),
                      companyAddress: _optional(address.text),
                      companyPostalCode: _optional(postalCode.text),
                      companyLocality: _optional(locality.text),
                      revenueLastYearCents: _euroCents(revenueLastYear.text),
                      revenueThisYearCents: _euroCents(revenueThisYear.text),
                      maintenanceLastYearCents: _euroCents(
                        maintenanceLastYear.text,
                      ),
                      fixedMonthlyCostsCents: _euroCents(
                        fixedMonthlyCosts.text,
                      ),
                    );
                Navigator.pop(context);
              },
              icon: const Icon(Icons.task_alt),
              label: const Text('Guardar dados'),
            ),
          ],
        ),
      ),
    );
  }
}

String _euros(int? cents) =>
    cents == null ? '' : (cents / 100).toStringAsFixed(2).replaceAll('.', ',');

class MachinesPage extends ConsumerWidget {
  const MachinesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final machines = ref
        .watch(operationsProvider)
        .machines
        .where((m) => !m.archived);
    return _PageFrame(
      title: 'Máquinas',
      action: FilledButton.icon(
        onPressed: () => _machineDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Adicionar máquina'),
      ),
      child: ListView(
        children: [
          for (final m in machines)
            Card(
              child: ListTile(
                minLeadingWidth: 70,
                leading: _MachineThumbnail(machine: m),
                title: Text(m.name),
                subtitle: Text('${m.category} · ${m.reference}'),
                trailing: Wrap(
                  children: [
                    Chip(label: Text(m.status.name)),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _machineDialog(context, ref, m),
                    ),
                    IconButton(
                      icon: const Icon(Icons.archive_outlined),
                      onPressed: () => ref
                          .read(operationsProvider.notifier)
                          .archiveMachine(m.id),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MachineThumbnail extends StatelessWidget {
  const _MachineThumbnail({required this.machine});
  final Machine machine;

  @override
  Widget build(BuildContext context) {
    final path = machine.photoPaths.isEmpty ? null : machine.photoPaths.first;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 64,
        height: 64,
        child: path == null
            ? ColoredBox(
                color: const Color(0xFFFFE5BD),
                child: Icon(
                  Icons.precision_manufacturing_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            : Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: const Color(0xFFFFE5BD),
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
      ),
    );
  }
}

Future<void> _machineDialog(
  BuildContext context,
  WidgetRef ref, [
  Machine? current,
]) async {
  final name = TextEditingController(text: current?.name);
  final reference = TextEditingController(text: current?.reference);
  final category = TextEditingController(text: current?.category);
  final dailyRate = TextEditingController(
    text: current?.dailyRateCents == null
        ? ''
        : (current!.dailyRateCents! / 100).toStringAsFixed(2),
  );
  final notes = TextEditingController(text: current?.notes);
  var status = current?.status ?? MachineStatus.available;
  final photoPaths = ValueNotifier<List<String>>(
    List<String>.of(current?.photoPaths ?? const []),
  );
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text(current == null ? 'Nova máquina' : 'Editar máquina'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          TextField(
            controller: reference,
            decoration: const InputDecoration(
              labelText: 'Número interno ou série',
            ),
          ),
          TextField(
            controller: category,
            decoration: const InputDecoration(labelText: 'Categoria'),
          ),
          TextField(
            controller: dailyRate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Preço diário de aluguer (€)',
            ),
          ),
          TextField(
            controller: notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notas / manutenção'),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<List<String>>(
            valueListenable: photoPaths,
            builder: (context, paths, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paths.isEmpty
                      ? 'Fotografia principal pendente'
                      : 'Fotografias da máquina (${paths.length})',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                if (paths.isNotEmpty)
                  SizedBox(
                    height: 78,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: paths.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) => Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(paths[index]),
                              width: 78,
                              height: 78,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const ColoredBox(
                                color: Color(0xFFFFE5BD),
                                child: SizedBox(
                                  width: 78,
                                  height: 78,
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Material(
                              color: Colors.black54,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => photoPaths.value = [
                                  for (var i = 0; i < paths.length; i++)
                                    if (i != index) paths[i],
                                ],
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (Platform.isAndroid || Platform.isIOS)
                      OutlinedButton.icon(
                        onPressed: () async {
                          final path = await MachineImageStore.pickFromCamera();
                          if (path != null) photoPaths.value = [...paths, path];
                        },
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Tirar foto'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final path = Platform.isAndroid || Platform.isIOS
                            ? await MachineImageStore.pickFromGallery()
                            : await MachineImageStore.pickFromFiles();
                        if (path != null) photoPaths.value = [...paths, path];
                      },
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        Platform.isAndroid || Platform.isIOS
                            ? 'Galeria'
                            : 'Escolher imagem',
                      ),
                    ),
                  ],
                ),
                if (paths.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'A primeira fotografia é usada como identificação principal.',
                    ),
                  ),
              ],
            ),
          ),
          StatefulBuilder(
            builder: (_, set) => DropdownButtonFormField(
              value: status,
              items: MachineStatus.values
                  .map((v) => DropdownMenuItem(value: v, child: Text(v.name)))
                  .toList(),
              onChanged: (v) => set(() => status = v!),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (name.text.isNotEmpty) {
              ref
                  .read(operationsProvider.notifier)
                  .saveMachine(
                    Machine(
                      id:
                          current?.id ??
                          'm${DateTime.now().microsecondsSinceEpoch}',
                      name: name.text,
                      reference: reference.text,
                      category: category.text,
                      status: status,
                      dailyRateCents: _moneyCents(dailyRate.text),
                      notes: notes.text.trim(),
                      photoPaths: photoPaths.value,
                    ),
                  );
            }
            Navigator.pop(context);
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  name.dispose();
  reference.dispose();
  category.dispose();
  dailyRate.dispose();
  notes.dispose();
  photoPaths.dispose();
}

class ClientsPage extends ConsumerWidget {
  const ClientsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(operationsProvider);
    return _PageFrame(
      title: 'Clientes e leads',
      action: Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => _customerDialog(context, ref),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Novo cliente'),
          ),
          FilledButton.icon(
            onPressed: () => _leadDialog(context, ref),
            icon: const Icon(Icons.add_call),
            label: const Text('Novo lead'),
          ),
        ],
      ),
      child: ListView(
        children: [
          const Text('Clientes', style: TextStyle(fontWeight: FontWeight.w800)),
          for (final c in state.customers)
            Card(
              child: ListTile(
                title: Text(c.name),
                subtitle: Text(
                  [
                    c.phone,
                    [c.postalCode, c.locality]
                        .whereType<String>()
                        .where((value) => value.isNotEmpty)
                        .join(' '),
                  ].where((value) => value.isNotEmpty).join(' · '),
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('Leads', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          for (final l in state.leads)
            Card(
              child: ListTile(
                title: Text(l.name),
                subtitle: Text('${l.phone} · ${l.status.name}'),
                trailing: l.status == LeadStatus.converted
                    ? null
                    : TextButton(
                        onPressed: () => ref
                            .read(operationsProvider.notifier)
                            .convertLead(l),
                        child: const Text('Converter'),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> _customerDialog(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController();
  final phone = TextEditingController();
  final taxId = TextEditingController();
  final email = TextEditingController();
  final address = TextEditingController();
  final postalCode = TextEditingController();
  final locality = TextEditingController();
  final notes = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Novo cliente'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nome *'),
            ),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telemóvel'),
            ),
            TextField(
              controller: taxId,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'NIF'),
            ),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: address,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Morada'),
            ),
            TextField(
              controller: postalCode,
              decoration: const InputDecoration(labelText: 'Código-postal'),
            ),
            TextField(
              controller: locality,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Localidade'),
            ),
            TextField(
              controller: notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notas'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty) return;
            try {
              ref
                  .read(operationsProvider.notifier)
                  .addCustomer(
                    Customer(
                      id: 'c${DateTime.now().microsecondsSinceEpoch}',
                      name: name.text.trim(),
                      phone: phone.text.trim(),
                      taxId: taxId.text.trim().isEmpty
                          ? null
                          : taxId.text.trim(),
                      email: email.text.trim().isEmpty
                          ? null
                          : email.text.trim(),
                      address: address.text.trim().isEmpty
                          ? null
                          : address.text.trim(),
                      postalCode: postalCode.text.trim().isEmpty
                          ? null
                          : postalCode.text.trim(),
                      locality: locality.text.trim().isEmpty
                          ? null
                          : locality.text.trim(),
                      notes: notes.text.trim(),
                    ),
                  );
              Navigator.pop(dialogContext);
            } on StateError catch (error) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(error.message.toString())));
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  name.dispose();
  phone.dispose();
  taxId.dispose();
  email.dispose();
  notes.dispose();
}

Future<void> _leadDialog(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController();
  final phone = TextEditingController();
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Novo lead'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          TextField(
            controller: phone,
            decoration: const InputDecoration(labelText: 'Telemóvel'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (name.text.isNotEmpty && phone.text.isNotEmpty) {
              ref
                  .read(operationsProvider.notifier)
                  .addLead(
                    Lead(
                      id: 'l${DateTime.now().microsecondsSinceEpoch}',
                      name: name.text,
                      phone: phone.text,
                      status: LeadStatus.newLead,
                      createdAt: DateTime.now(),
                    ),
                  );
            }
            Navigator.pop(context);
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}

class BookingsPage extends ConsumerWidget {
  const BookingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(operationsProvider).bookings;
    return _PageFrame(
      title: 'Marcações / Reservas',
      action: FilledButton.icon(
        onPressed: () => showBookingForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nova marcação'),
      ),
      child: ListView(
        children: [
          for (final b in bookings)
            Card(
              child: ListTile(
                onTap: () => _bookingStatusDialog(context, ref, b),
                leading: const CircleAvatar(
                  child: Icon(Icons.calendar_month_outlined),
                ),
                title: Text(
                  '${b.startsAt.day}/${b.startsAt.month} — ${b.endsAt.day}/${b.endsAt.month}',
                ),
                subtitle: Text(b.status.name),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (b.expectedValueCents != null)
                      Text(
                        '${(b.expectedValueCents! / 100).toStringAsFixed(2)} €',
                      ),
                    Text(
                      b.customerNameSnapshot.isEmpty
                          ? 'Cliente por confirmar'
                          : b.customerNameSnapshot,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> _bookingStatusDialog(
  BuildContext context,
  WidgetRef ref,
  Booking booking,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Atualizar estado da reserva'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final status in BookingStatus.values)
            ListTile(
              title: Text(_bookingStatusLabel(status)),
              trailing: status == booking.status
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
              onTap: () {
                final conflict = ref
                    .read(operationsProvider.notifier)
                    .updateBookingStatus(booking.id, status);
                if (conflict != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Conflito: ${conflict.machine.name} está ocupada.',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext);
              },
            ),
        ],
      ),
    ),
  );
}

String _bookingStatusLabel(BookingStatus status) => switch (status) {
  BookingStatus.request => 'Pedido',
  BookingStatus.proposalSent => 'Proposta enviada',
  BookingStatus.confirmed => 'Confirmada',
  BookingStatus.rented => 'Em aluguer',
  BookingStatus.completed => 'Concluída',
  BookingStatus.cancelled => 'Cancelada',
};

Future<void> showBookingForm(
  BuildContext context,
  WidgetRef ref, {
  String? responsibleId,
}) async {
  final state = ref.read(operationsProvider);
  if (state.customers.isEmpty ||
      state.machines.where((m) => !m.archived).isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Regista primeiro pelo menos um cliente e uma máquina.'),
      ),
    );
    return;
  }
  var customerId = state.customers.first.id;
  var machineId = state.machines.firstWhere((m) => !m.archived).id;
  var status = BookingStatus.request;
  var startsAt = DateTime.now().add(const Duration(days: 1));
  var endsAt = startsAt.add(const Duration(days: 1));
  String? collaboratorId = responsibleId;
  final expectedValue = TextEditingController();
  final notes = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final availableMachines = state.machines
            .where(
              (machine) =>
                  !machine.archived &&
                  ref
                      .read(operationsProvider.notifier)
                      .machineAvailable(machine.id, startsAt, endsAt),
            )
            .toList();
        if (!availableMachines.any((machine) => machine.id == machineId)) {
          machineId = availableMachines.isNotEmpty
              ? availableMachines.first.id
              : state.machines.firstWhere((machine) => !machine.archived).id;
        }
        return AlertDialog(
          title: const Text('Nova marcação / reserva'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: customerId,
                    decoration: const InputDecoration(labelText: 'Cliente'),
                    items: state.customers
                        .map(
                          (customer) => DropdownMenuItem(
                            value: customer.id,
                            child: Text(customer.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => customerId = value!),
                  ),
                  DropdownButtonFormField<String>(
                    value: machineId,
                    decoration: const InputDecoration(labelText: 'Máquina'),
                    items:
                        (availableMachines.isEmpty
                                ? state.machines
                                      .where((machine) => !machine.archived)
                                      .toList()
                                : availableMachines)
                            .map(
                              (machine) => DropdownMenuItem(
                                value: machine.id,
                                child: Text(
                                  '${machine.name} · ${machine.reference}',
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: availableMachines.isEmpty
                        ? null
                        : (value) => setDialogState(() => machineId = value!),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Período'),
                    subtitle: Text('${_date(startsAt)} a ${_date(endsAt)}'),
                    trailing: const Icon(Icons.date_range_outlined),
                    onTap: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 1),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                        initialDateRange: DateTimeRange(
                          start: startsAt,
                          end: endsAt,
                        ),
                      );
                      if (range != null) {
                        setDialogState(() {
                          startsAt = range.start;
                          endsAt = range.end.add(const Duration(days: 1));
                        });
                      }
                    },
                  ),
                  DropdownButtonFormField<BookingStatus>(
                    value: status,
                    decoration: const InputDecoration(
                      labelText: 'Estado inicial',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: BookingStatus.request,
                        child: Text('Pedido'),
                      ),
                      DropdownMenuItem(
                        value: BookingStatus.proposalSent,
                        child: Text('Proposta enviada'),
                      ),
                      DropdownMenuItem(
                        value: BookingStatus.confirmed,
                        child: Text('Confirmada'),
                      ),
                    ],
                    onChanged: (value) => setDialogState(() => status = value!),
                  ),
                  DropdownButtonFormField<String?>(
                    value: collaboratorId,
                    decoration: const InputDecoration(labelText: 'Responsável'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Gestor'),
                      ),
                      ...state.collaborators
                          .where((collaborator) => !collaborator.archived)
                          .map(
                            (collaborator) => DropdownMenuItem<String?>(
                              value: collaborator.id,
                              child: Text(collaborator.name),
                            ),
                          ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => collaboratorId = value),
                  ),
                  TextField(
                    controller: expectedValue,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Valor previsto (€)',
                    ),
                  ),
                  TextField(
                    controller: notes,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Notas'),
                  ),
                  if (availableMachines.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text('Não há máquinas disponíveis neste período.'),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: availableMachines.isEmpty
                  ? null
                  : () {
                      final cents =
                          ((double.tryParse(
                                        expectedValue.text.replaceAll(',', '.'),
                                      ) ??
                                      0) *
                                  100)
                              .round();
                      final conflict = ref
                          .read(operationsProvider.notifier)
                          .addBooking(
                            Booking(
                              id: 'b${DateTime.now().microsecondsSinceEpoch}',
                              customerId: customerId,
                              machineIds: [machineId],
                              startsAt: startsAt,
                              endsAt: endsAt,
                              status: status,
                              expectedValueCents: cents > 0 ? cents : null,
                              collaboratorResponsibleId: collaboratorId,
                              notes: notes.text.trim(),
                            ),
                          );
                      if (conflict != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Conflito: ${conflict.machine.name} já está ocupada.',
                            ),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(dialogContext);
                    },
              child: const Text('Guardar marcação'),
            ),
          ],
        );
      },
    ),
  );
  expectedValue.dispose();
  notes.dispose();
}

int? _moneyCents(String value) {
  if (value.trim().isEmpty) return null;
  final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
  return parsed == null || parsed < 0 ? null : (parsed * 100).round();
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

// ignore: unused_element
Future<void> _bookingDialog(BuildContext context, WidgetRef ref) async {
  final state = ref.read(operationsProvider);
  final start = DateTime.now().add(const Duration(days: 1));
  final end = start.add(const Duration(days: 1));
  final available = state.machines
      .where(
        (m) => ref
            .read(operationsProvider.notifier)
            .machineAvailable(m.id, start, end),
      )
      .toList();
  if (state.customers.isEmpty || available.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('É necessário um cliente e uma máquina disponível.'),
      ),
    );
    return;
  }
  final selected = available.first;
  final conflict = ref
      .read(operationsProvider.notifier)
      .addBooking(
        Booking(
          id: 'b${DateTime.now().microsecondsSinceEpoch}',
          customerId: state.customers.first.id,
          machineIds: [selected.id],
          startsAt: start,
          endsAt: end,
          status: BookingStatus.confirmed,
        ),
      );
  if (conflict != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Conflito: ${conflict.machine.name} está ocupada.'),
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({
    required this.title,
    required this.action,
    required this.child,
  });
  final String title;
  final Widget action, child;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              action,
            ],
          ),
          const SizedBox(height: 18),
          Expanded(child: child),
        ],
      ),
    ),
  );
}
