import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/machine_image_store.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../domain/models/operations.dart';
import '../../../domain/models/historical_month.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});
  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  int step = 0, collaborators = 0, machines = 0, vehicles = 0;
  // Se o gestor não quer/não tem tempo agora, salta os passos financeiros e
  // operacionais (máquinas + facturação + manutenção + custos).
  // A ideia é deixá-lo entrar na app cedo e ganhar confiança primeiro.
  bool wantsFullSetup = true;
  String legal = 'Empresário em Nome Individual';
  // fleet fica derivado de vehicles > 0 na hora de gravar (para não mudar
  // o contrato de completeOnboarding).
  // Cargo declarado pelo utilizador logo no início do onboarding.
  // Em modo demo o valor fica só no state (não bloqueia nada por agora).
  // Quando a app for para Supabase real, o cargo autoritativo vem de
  // punho_membros — este é ignorado ou usado só como sugestão.
  String role = 'gestor';
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
    // Fluxo:
    //   0 - nome do utilizador
    //   1 - nome da empresa
    //   2 - cargo (gestor / colaborador)
    //   [se colaborador termina aqui — não sabe nem tem de saber NIF, morada,
    //    facturação ou custos da empresa. Isso é do gestor.]
    //   3+ - só para gestor: dados administrativos + operacionais
    const titlesFull = [
      'Como te chamas?',
      'Como se chama a empresa?',
      'Qual é o teu cargo?',
      'Forma jurídica e NIF da empresa',
      'Morada e contactos da empresa',
      'Equipa e frota',
      'Continuar com os dados operacionais?',
      'Quantas máquinas tem aproximadamente?',
      'Quanto faturou no ano passado?',
      'Quanto faturou este ano até hoje?',
      'Quanto gastou em manutenção no ano passado?',
      'Quais são os custos fixos mensais?',
    ];
    const helpsFull = [
      'O Punho orienta a pessoa responsável por decidir e agir na empresa.',
      'Usamos este nome para personalizar o espaço de gestão.',
      'O gestor decide e vê tudo. O colaborador só regista o seu próprio trabalho.',
      'A forma jurídica pode ser alterada mais tarde. O NIF é importante para a identificação — se não souber agora, ficará como tarefa aberta.',
      'Morada, código-postal e localidade + telemóvel e email. Não é pedido país.',
      'Número de colaboradores e de veículos (podem ser 0). Os separadores Funcionários e Veículos ficam activos quando forem maiores que 0.',
      'Sem os próximos dados (máquinas, faturação, custos), a app abre e podes explorar, mas o Punho não consegue mostrar recomendações reais nem tirar todo o potencial. Podes preencher agora ou deixar para depois.',
      'Uma estimativa é suficiente; não precisa de ser exata. Podes adicionar cada máquina em detalhe mais tarde na secção Máquinas.',
      'Pode indicar um número redondo. Se não souber, avance: o Punho irá lembrar-lhe.',
      'Indique o acumulado deste ano até ao momento. Pode preencher mais tarde.',
      'Mesmo uma estimativa ajuda a perceber o peso real das avarias e revisões.',
      'Renda, eletricidade, água, seguros, programas e outros custos recorrentes. Uma estimativa chega.',
    ];
    // Colaborador: 4 passos (nome, empresa, cargo, contacto telefónico
    // pessoal — para o gestor o poder contactar). O resto — dados fiscais,
    // faturação, custos — é responsabilidade do gestor, não é sequer pedido.
    const titlesColab = [
      'Como te chamas?',
      'Como se chama a empresa?',
      'Qual é o teu cargo?',
      'Qual é o teu contacto telefónico?',
    ];
    const helpsColab = [
      'O Punho orienta a pessoa responsável por decidir e agir na empresa.',
      'Usamos este nome para personalizar o espaço de gestão.',
      'O gestor decide e vê tudo. O colaborador só regista o seu próprio trabalho.',
      'O gestor precisa deste contacto para te chegar quando for preciso.',
    ];
    // Gestor que declarou não ter tempo agora: termina no passo 7 (o próprio
    // switch), sem entrar nos campos financeiros. Fica lá para preencher
    // depois, na secção Gestão.
    final gestorTitles = wantsFullSetup ? titlesFull : titlesFull.sublist(0, 7);
    final gestorHelps = wantsFullSetup ? helpsFull : helpsFull.sublist(0, 7);
    final titles = role == 'colaborador' ? titlesColab : gestorTitles;
    final helps = role == 'colaborador' ? helpsColab : gestorHelps;
    final input = switch (step) {
      0 => TextField(
        controller: ownerName,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Nome',
          border: OutlineInputBorder(),
        ),
      ),
      1 => TextField(
        controller: name,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Nome da empresa',
          border: OutlineInputBorder(),
        ),
      ),
      2 => DropdownButtonFormField<String>(
        value: role,
        decoration: const InputDecoration(
          labelText: 'O teu cargo',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'gestor', child: Text('Gestor')),
          DropdownMenuItem(value: 'colaborador', child: Text('Colaborador')),
        ],
        onChanged: (v) => setState(() => role = v ?? 'gestor'),
      ),
      // Passo 3 ramifica pelo cargo:
      //   colaborador → contacto pessoal (último passo dele)
      //   gestor → forma jurídica + NIF juntos (menos ecrãs para dados que
      //   pertencem ao mesmo bloco administrativo)
      3 => role == 'colaborador'
          ? TextField(
              controller: phone,
              autofocus: true,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telemóvel',
                border: OutlineInputBorder(),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: legal,
                  decoration: const InputDecoration(
                    labelText: 'Forma jurídica',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Empresário em Nome Individual',
                      child: Text('Empresário em Nome Individual'),
                    ),
                    DropdownMenuItem(value: 'Lda.', child: Text('Lda.')),
                  ],
                  onChanged: (v) => setState(() => legal = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: taxId,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'NIF da empresa',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
      // Passo 4 (só gestor): morada + contactos juntos.
      4 => Column(
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: postalCode,
                  decoration: const InputDecoration(
                    labelText: 'Código-postal',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: locality,
                  decoration: const InputDecoration(
                    labelText: 'Localidade',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
      // Passo 5 (só gestor): equipa + frota, ambos como número (default 0).
      // Veículos deixou de ser um switch — o número serve tanto para saber
      // se a área Veículos deve aparecer (>0) como para calcular custos.
      5 => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NumberChoice(
            label: 'Colaboradores',
            value: collaborators,
            onChanged: (v) => setState(() => collaborators = v),
          ),
          const SizedBox(height: 12),
          _NumberChoice(
            label: 'Veículos',
            value: vehicles,
            onChanged: (v) => setState(() => vehicles = v),
          ),
        ],
      ),
      // Passo 6 (só gestor): switch de decisão. Se OFF, titles.length cai
      // para 7 e o botão passa a "Concluir" — o utilizador entra na app
      // sem preencher máquinas/faturação/custos.
      // Cor verde no thumb+track quando ON: torna claro visualmente que a
      // opção "sim, preencher" está seleccionada. Cinza (default) para OFF.
      6 => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          wantsFullSetup
              ? 'Sim, quero preencher agora'
              : 'Não, entro na app e preencho depois',
        ),
        value: wantsFullSetup,
        activeColor: Colors.green.shade600,
        activeTrackColor: Colors.green.shade200,
        onChanged: (v) => setState(() => wantsFullSetup = v),
      ),
      7 => _NumberChoice(
        label: 'Número aproximado de máquinas',
        value: machines,
        onChanged: (v) => setState(() => machines = v),
      ),
      8 => _EuroInput(
        controller: revenueLastYear,
        label: 'Faturação no ano passado (€)',
      ),
      9 => _EuroInput(
        controller: revenueThisYear,
        label: 'Faturação deste ano até hoje (€)',
      ),
      10 => _EuroInput(
        controller: maintenanceLastYear,
        label: 'Manutenção paga no ano passado (€)',
      ),
      // Custos fixos é o último passo do onboarding completo — daqui vai
      // directo para a app, sem passar por "quer inserir máquinas agora?".
      // O utilizador adiciona máquinas em detalhe na secção Máquinas quando
      // quiser (assim não é forçado a fazê-lo já no onboarding).
      _ => _EuroInput(
        controller: fixedMonthlyCosts,
        label: 'Custos fixos mensais (€)',
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
                                hasFleet: vehicles > 0,
                                declaredVehicleCount: vehicles,
                                collaborators: collaborators,
                                totalMachinesDeclared: machines,
                                // Sempre false: o passo "inserir máquinas
                                // agora" foi removido. Utilizador adiciona
                                // máquinas em detalhe (foto, referência,
                                // etc.) na secção Máquinas ao seu ritmo.
                                insertMachinesNow: false,
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
    // Foco imediato para o utilizador escrever logo sem ter de tocar primeiro
    // no campo. Como o input é o único widget do passo, não há ambiguidade.
    autofocus: true,
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
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoricalDataPage()),
              ),
              icon: const Icon(Icons.history_outlined),
              label: const Text('Preencher histórico mensal'),
            ),
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

int? _wholeNumber(String value) {
  final parsed = int.tryParse(value.trim());
  return parsed == null || parsed < 0 ? null : parsed;
}

class HistoricalDataPage extends ConsumerStatefulWidget {
  const HistoricalDataPage({super.key});

  @override
  ConsumerState<HistoricalDataPage> createState() => _HistoricalDataPageState();
}

class _HistoricalDataPageState extends ConsumerState<HistoricalDataPage> {
  late int year;

  @override
  void initState() {
    super.initState();
    year = DateTime.now().year - 1;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(operationsProvider);
    final years = List<int>.generate(
      6,
      (index) => DateTime.now().year - 5 + index,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico mensal')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Preenche o histórico aos poucos. O Punho só mostra comparações homólogas quando existe um mês real para comparar.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<int>(
              value: year,
              decoration: const InputDecoration(labelText: 'Ano'),
              items: [
                for (final item in years)
                  DropdownMenuItem(value: item, child: Text('$item')),
              ],
              onChanged: (value) => setState(() => year = value!),
            ),
            const SizedBox(height: 10),
            const Text(
              'Os valores são recebimentos e despesas efetivamente pagos. Pode usar estimativas redondas se ainda não tiver os extratos.',
            ),
            const SizedBox(height: 12),
            for (var month = 1; month <= 12; month++)
              _HistoricalMonthEditor(
                key: ValueKey('$year-$month'),
                initial: state.historicalMonth(year, month),
                year: year,
                month: month,
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoricalMonthEditor extends ConsumerStatefulWidget {
  const _HistoricalMonthEditor({
    super.key,
    required this.initial,
    required this.year,
    required this.month,
  });
  final HistoricalMonth? initial;
  final int year, month;

  @override
  ConsumerState<_HistoricalMonthEditor> createState() =>
      _HistoricalMonthEditorState();
}

class _HistoricalMonthEditorState
    extends ConsumerState<_HistoricalMonthEditor> {
  late final TextEditingController revenue;
  late final TextEditingController expenses;
  late final TextEditingController advertising;
  late final TextEditingController leads;
  late final TextEditingController converted;
  late final TextEditingController maintenance;

  @override
  void initState() {
    super.initState();
    final item = widget.initial;
    revenue = TextEditingController(text: _euros(item?.revenueReceivedCents));
    expenses = TextEditingController(text: _euros(item?.paidExpensesCents));
    advertising = TextEditingController(
      text: _euros(item?.advertisingSpendCents),
    );
    leads = TextEditingController(text: item?.leadsReceived?.toString() ?? '');
    converted = TextEditingController(
      text: item?.convertedLeads?.toString() ?? '',
    );
    maintenance = TextEditingController(text: _euros(item?.maintenanceCents));
  }

  @override
  void dispose() {
    for (final controller in [
      revenue,
      expenses,
      advertising,
      leads,
      converted,
      maintenance,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saved = widget.initial?.hasAnyData == true;
    return Card(
      child: ExpansionTile(
        title: Text(monthName(widget.month)),
        subtitle: Text(
          saved ? 'Dados guardados — pode corrigir' : 'Por preencher',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _EuroInput(controller: revenue, label: 'Recebimentos (€)'),
          _EuroInput(controller: expenses, label: 'Despesas pagas (€)'),
          _EuroInput(controller: advertising, label: 'Publicidade (€)'),
          TextField(
            controller: leads,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Leads recebidas'),
          ),
          TextField(
            controller: converted,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Leads convertidas em reserva',
            ),
          ),
          _EuroInput(controller: maintenance, label: 'Manutenção paga (€)'),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () {
                ref
                    .read(operationsProvider.notifier)
                    .saveHistoricalMonth(
                      HistoricalMonth(
                        year: widget.year,
                        month: widget.month,
                        revenueReceivedCents: _euroCents(revenue.text),
                        paidExpensesCents: _euroCents(expenses.text),
                        advertisingSpendCents: _euroCents(advertising.text),
                        leadsReceived: _wholeNumber(leads.text),
                        convertedLeads: _wholeNumber(converted.text),
                        maintenanceCents: _euroCents(maintenance.text),
                      ),
                    );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${monthName(widget.month)} guardado.'),
                  ),
                );
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar mês'),
            ),
          ),
        ],
      ),
    );
  }
}

String monthName(int month) => const [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
][month - 1];

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
                // maxLines+ellipsis obrigatórios: sem eles o Flutter parte o
                // texto em coluna vertical de caracteres quando o trailing
                // (chip + 4 botões) rouba a largura toda em ecrãs estreitos.
                title: Text(
                  m.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${m.category} · ${m.reference}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MachineStatusChip(status: m.status),
                    if (m.status == MachineStatus.stopped)
                      TextButton.icon(
                        onPressed: () {
                          final changed = ref
                              .read(operationsProvider.notifier)
                              .updateMachineStatus(
                                m.id,
                                MachineStatus.available,
                              );
                          if (!changed) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'A máquina tem uma reserva ativa e não pode ficar disponível.',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text('Disponível'),
                      ),
                    PopupMenuButton<MachineStatus>(
                      tooltip: 'Mudar estado',
                      icon: const Icon(Icons.swap_horiz),
                      onSelected: (status) {
                        final changed = ref
                            .read(operationsProvider.notifier)
                            .updateMachineStatus(m.id, status);
                        if (!changed) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'A máquina tem uma reserva ativa e não pode ficar disponível.',
                              ),
                            ),
                          );
                        }
                      },
                      itemBuilder: (_) => [
                        for (final status in MachineStatus.values)
                          PopupMenuItem(
                            value: status,
                            child: Text(machineStatusLabel(status)),
                          ),
                      ],
                    ),
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

class _MachineStatusChip extends StatelessWidget {
  const _MachineStatusChip({required this.status});
  final MachineStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      MachineStatus.available => Colors.green.shade700,
      MachineStatus.reserved => Colors.blue.shade700,
      MachineStatus.rented => Colors.deepPurple.shade700,
      MachineStatus.maintenance => Colors.orange.shade800,
      MachineStatus.stopped => Theme.of(context).colorScheme.error,
    };
    return Chip(
      avatar: Icon(Icons.circle, size: 10, color: color),
      label: Text(machineStatusLabel(status)),
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
            : _MachinePhoto(path: path, fit: BoxFit.cover),
      ),
    );
  }
}

class _MachinePhoto extends StatelessWidget {
  const _MachinePhoto({
    required this.path,
    this.width,
    this.height,
    required this.fit,
  });

  final String path;
  final double? width, height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    Widget unavailable() => const ColoredBox(
      color: Color(0xFFFFE5BD),
      child: Center(child: Icon(Icons.image_not_supported_outlined)),
    );
    if (!MachineImageStore.isRemotePath(path)) {
      return Image.file(
        File(path),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => unavailable(),
      );
    }
    return FutureBuilder<String?>(
      future: MachineImageStore.signedUrl(path),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return unavailable();
        return Image.network(
          snapshot.data!,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, _, _) => unavailable(),
        );
      },
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
                            child: _MachinePhoto(
                              path: paths[index],
                              width: 78,
                              height: 78,
                              fit: BoxFit.cover,
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
                          try {
                            final path = await MachineImageStore.pickFromCamera();
                            if (path != null) photoPaths.value = [...paths, path];
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('NÃ£o foi possÃ­vel enviar a fotografia para o arquivo da empresa.'),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Tirar foto'),
                      ),
                    OutlinedButton.icon(
                        onPressed: () async {
                        try {
                          final path = Platform.isAndroid || Platform.isIOS
                              ? await MachineImageStore.pickFromGallery()
                              : await MachineImageStore.pickFromFiles();
                          if (path != null) photoPaths.value = [...paths, path];
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('NÃ£o foi possÃ­vel enviar a fotografia para o arquivo da empresa.'),
                              ),
                            );
                          }
                        }
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
            builder: (_, set) => DropdownButtonFormField<MachineStatus>(
              value: status,
              decoration: const InputDecoration(labelText: 'Estado atual'),
              items: MachineStatus.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(machineStatusLabel(value)),
                    ),
                  )
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
            if (name.text.trim().isEmpty) {
              // Antes fechava o diálogo em silêncio e deitava fora o que
              // tinha sido escrito.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Indica o nome da máquina.')),
              );
              return;
            }
            // A editar usa-se copyWith: construir um Machine novo apagava a
            // data de aquisição e desarquivava máquinas arquivadas.
            final machine = current != null
                ? current.copyWith(
                    name: name.text.trim(),
                    reference: reference.text,
                    category: category.text,
                    status: status,
                    dailyRateCents: _moneyCents(dailyRate.text),
                    notes: notes.text.trim(),
                    photoPaths: photoPaths.value,
                  )
                : Machine(
                    id: 'm${DateTime.now().microsecondsSinceEpoch}',
                    name: name.text.trim(),
                    reference: reference.text,
                    category: category.text,
                    status: status,
                    dailyRateCents: _moneyCents(dailyRate.text),
                    notes: notes.text.trim(),
                    photoPaths: photoPaths.value,
                  );
            ref.read(operationsProvider.notifier).saveMachine(machine);
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
                        onPressed: () {
                          try {
                            ref
                                .read(operationsProvider.notifier)
                                .convertLead(l);
                          } on StateError catch (error) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.message)),
                            );
                          }
                        },
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

class BookingsPage extends ConsumerStatefulWidget {
  const BookingsPage({super.key, this.responsibleId});
  final String? responsibleId;

  @override
  ConsumerState<BookingsPage> createState() => _BookingsPageState();
}

enum _CalendarView { week, month }

class _BookingsPageState extends ConsumerState<BookingsPage> {
  var _view = _CalendarView.week;
  var _focus = DateUtils.dateOnly(DateTime.now());
  String? _selectedMachineId;
  final Set<DateTime> _selectedSlotStarts = {};

  Machine? _selectedMachine(OperationsState state) {
    final matches = state.machines.where(
      (machine) => machine.id == _selectedMachineId && !machine.archived,
    );
    return matches.isEmpty ? null : matches.first;
  }

  bool _machineCanReceiveReservation(Machine machine) =>
      machine.status != MachineStatus.maintenance &&
      machine.status != MachineStatus.stopped &&
      machine.status != MachineStatus.rented;

  void _toggleSlot(BuildContext context, DateTime startsAt) {
    setState(() {
      if (!_selectedSlotStarts.add(startsAt)) {
        _selectedSlotStarts.remove(startsAt);
      }
    });
  }

  void _clearSelection() => setState(_selectedSlotStarts.clear);

  DateTimeRange? get _selectedPeriod {
    if (_selectedSlotStarts.isEmpty ||
        !_isContiguousHalfDaySelection(_selectedSlotStarts)) {
      return null;
    }
    final ordered = _selectedSlotStarts.toList()..sort();
    return DateTimeRange(
      start: ordered.first,
      end: ordered.last.add(const Duration(hours: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(operationsProvider);
    final selectedMachine = _selectedMachine(state);
    final period = _selectedPeriod;
    final canAdd =
        selectedMachine != null &&
        _machineCanReceiveReservation(selectedMachine) &&
        period != null;
    return _PageFrame(
      title: 'Marcações / Reservas',
      action: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (_selectedSlotStarts.isNotEmpty)
            TextButton(
              onPressed: _clearSelection,
              child: const Text('Limpar seleção'),
            ),
          FilledButton.icon(
            onPressed: !canAdd
                ? null
                : () async {
                    final saved = await _showCalendarBookingConfirmation(
                      context,
                      ref,
                      machine: selectedMachine,
                      startsAt: period.start,
                      endsAt: period.end,
                      responsibleId: widget.responsibleId,
                    );
                    if (mounted && saved) _clearSelection();
                  },
            icon: const Icon(Icons.add),
            label: Text(
              _selectedSlotStarts.isEmpty
                  ? 'Adicionar reserva'
                  : 'Adicionar (${_selectedSlotStarts.length})',
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          _CalendarToolbar(
            focus: _focus,
            view: _view,
            onPrevious: () => setState(
              () => _focus = _view == _CalendarView.week
                  ? _focus.subtract(const Duration(days: 7))
                  : DateTime(_focus.year, _focus.month - 1, 1),
            ),
            onNext: () => setState(
              () => _focus = _view == _CalendarView.week
                  ? _focus.add(const Duration(days: 7))
                  : DateTime(_focus.year, _focus.month + 1, 1),
            ),
            onViewChanged: (view) => setState(() => _view = view),
          ),
          const SizedBox(height: 12),
          _MachineReservationSelector(
            machines: state.machines
                .where((machine) => !machine.archived)
                .toList(),
            selectedMachineId: _selectedMachineId,
            onSelected: (machineId) => setState(() {
              _selectedMachineId = machineId;
              _selectedSlotStarts.clear();
            }),
          ),
          const SizedBox(height: 10),
          if (selectedMachine == null)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Escolhe uma máquina para marcar os períodos livres.',
              ),
            )
          else if (!_machineCanReceiveReservation(selectedMachine))
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${selectedMachine.reference} está ${machineStatusLabel(selectedMachine.status).toLowerCase()} e não pode receber reservas.',
              ),
            )
          else if (_selectedSlotStarts.isNotEmpty && period == null)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Escolhe períodos consecutivos para criar uma única reserva.',
              ),
            )
          else if (period != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${selectedMachine.reference} · ${_calendarPeriodLabel(period)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: _view == _CalendarView.week
                ? _WeekBookingsCalendar(
                    focus: _focus,
                    bookings: state.bookings,
                    machineId: _selectedMachineId,
                    selectedSlotStarts: _selectedSlotStarts,
                    onToggleSlot:
                        selectedMachine == null ||
                            !_machineCanReceiveReservation(selectedMachine)
                        ? null
                        : (startsAt) => _toggleSlot(context, startsAt),
                  )
                : _MonthBookingsCalendar(
                    focus: _focus,
                    bookings: state.bookings,
                    machineId: _selectedMachineId,
                    onDaySelected: (day) => setState(() {
                      _focus = day;
                      _view = _CalendarView.week;
                    }),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MachineReservationSelector extends StatelessWidget {
  const _MachineReservationSelector({
    required this.machines,
    required this.selectedMachineId,
    required this.onSelected,
  });
  final List<Machine> machines;
  final String? selectedMachineId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (machines.isEmpty) {
      return const Text('Ainda não existem máquinas identificadas.');
    }
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: machines.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final machine = machines[index];
          final selected = machine.id == selectedMachineId;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => onSelected(machine.id),
            avatar: Icon(
              machine.status == MachineStatus.available
                  ? Icons.precision_manufacturing_outlined
                  : Icons.build_circle_outlined,
              size: 18,
            ),
            label: SizedBox(
              width: 128,
              child: Text(
                '${machine.reference}\n${machineStatusLabel(machine.status)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CalendarToolbar extends StatelessWidget {
  const _CalendarToolbar({
    required this.focus,
    required this.view,
    required this.onPrevious,
    required this.onNext,
    required this.onViewChanged,
  });
  final DateTime focus;
  final _CalendarView view;
  final VoidCallback onPrevious, onNext;
  final ValueChanged<_CalendarView> onViewChanged;

  @override
  Widget build(BuildContext context) {
    final weekStart = _weekStart(focus);
    final label = view == _CalendarView.week
        ? '${_date(weekStart)} a ${_date(weekStart.add(const Duration(days: 6)))}'
        : '${monthName(focus.month)} ${focus.year}';
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Período anterior',
            ),
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Período seguinte',
            ),
          ],
        ),
        ToggleButtons(
          isSelected: [view == _CalendarView.week, view == _CalendarView.month],
          onPressed: (index) => onViewChanged(_CalendarView.values[index]),
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('Semana'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('Mês'),
            ),
          ],
        ),
      ],
    );
  }
}

class _WeekBookingsCalendar extends ConsumerWidget {
  const _WeekBookingsCalendar({
    required this.focus,
    required this.bookings,
    required this.machineId,
    required this.selectedSlotStarts,
    required this.onToggleSlot,
  });
  final DateTime focus;
  final List<Booking> bookings;
  final String? machineId;
  final Set<DateTime> selectedSlotStarts;
  final ValueChanged<DateTime>? onToggleSlot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final start = _weekStart(focus);
    final days = List.generate(7, (index) => start.add(Duration(days: index)));
    final state = ref.watch(operationsProvider);
    final machineBookings = machineId == null
        ? const <Booking>[]
        : bookings
              .where((booking) => booking.machineIds.contains(machineId))
              .toList();
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: constraints.maxWidth < 860 ? 860 : constraints.maxWidth,
          child: SingleChildScrollView(
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 86),
                    for (final day in days)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(
                            '${_weekDay(day)}\n${day.day}/${day.month}',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                      ),
                  ],
                ),
                _WeekSlotRow(
                  label: 'Manhã',
                  days: days,
                  slot: _HalfDay.morning,
                  bookings: machineBookings,
                  state: state,
                  selectedSlotStarts: selectedSlotStarts,
                  onToggleSlot: onToggleSlot,
                ),
                _WeekSlotRow(
                  label: 'Tarde',
                  days: days,
                  slot: _HalfDay.afternoon,
                  bookings: machineBookings,
                  state: state,
                  selectedSlotStarts: selectedSlotStarts,
                  onToggleSlot: onToggleSlot,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekSlotRow extends ConsumerWidget {
  const _WeekSlotRow({
    required this.label,
    required this.days,
    required this.slot,
    required this.bookings,
    required this.state,
    required this.selectedSlotStarts,
    required this.onToggleSlot,
  });
  final String label;
  final List<DateTime> days;
  final _HalfDay slot;
  final List<Booking> bookings;
  final OperationsState state;
  final Set<DateTime> selectedSlotStarts;
  final ValueChanged<DateTime>? onToggleSlot;

  @override
  // IntrinsicHeight é obrigatório aqui: a linha vive dentro de um
  // SingleChildScrollView vertical, que lhe dá altura infinita, e o
  // `stretch` transformava isso numa constraint apertada de altura infinita
  // — constraints inválidas e o calendário da semana rebentava a montar.
  // O IntrinsicHeight resolve a altura da célula mais alta antes do stretch.
  Widget build(BuildContext context, WidgetRef ref) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 86,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        for (final day in days)
          Expanded(
            child: _BookingSlotCell(
              day: day,
              slot: slot,
              bookings: bookings
                  .where((booking) => _overlapsSlot(booking, day, slot))
                  .toList(),
              state: state,
              selected: selectedSlotStarts.contains(_slotStartsAt(day, slot)),
              onToggle: onToggleSlot == null
                  ? null
                  : () => onToggleSlot!(_slotStartsAt(day, slot)),
            ),
          ),
      ],
    ),
  );
}

class _BookingSlotCell extends ConsumerWidget {
  const _BookingSlotCell({
    required this.day,
    required this.slot,
    required this.bookings,
    required this.state,
    required this.selected,
    required this.onToggle,
  });
  final DateTime day;
  final _HalfDay slot;
  final List<Booking> bookings;
  final OperationsState state;
  final bool selected;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) => InkWell(
    onTap: bookings.isEmpty ? onToggle : null,
    child: Container(
      constraints: const BoxConstraints(minHeight: 116),
      margin: const EdgeInsets.all(3),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: bookings.isEmpty
          ? Center(
              child: selected
                  ? Icon(
                      Icons.check_circle,
                      size: 22,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : Icon(
                      Icons.add_circle_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final booking in bookings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: InkWell(
                      onTap: () => _bookingStatusDialog(context, ref, booking),
                      child: _BookingEventChip(booking: booking, state: state),
                    ),
                  ),
              ],
            ),
    ),
  );
}

class _MonthBookingsCalendar extends ConsumerWidget {
  const _MonthBookingsCalendar({
    required this.focus,
    required this.bookings,
    required this.machineId,
    required this.onDaySelected,
  });
  final DateTime focus;
  final List<Booking> bookings;
  final String? machineId;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = DateTime(focus.year, focus.month);
    final start = _weekStart(first);
    final state = ref.watch(operationsProvider);
    final machineBookings = machineId == null
        ? const <Booking>[]
        : bookings
              .where((booking) => booking.machineIds.contains(machineId))
              .toList();
    return Column(
      children: [
        Row(
          children: [
            for (final day in ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'])
              Expanded(child: Center(child: Text(day))),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.95,
            ),
            itemCount: 42,
            itemBuilder: (context, index) {
              final day = start.add(Duration(days: index));
              final dayBookings = machineBookings
                  .where((booking) => _overlapsDay(booking, day))
                  .toList();
              return InkWell(
                onTap: () => onDaySelected(day),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: day.month == focus.month
                        ? null
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${day.day}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      for (final booking in dayBookings.take(2))
                        _BookingEventChip(booking: booking, state: state),
                      if (dayBookings.length > 2)
                        Text(
                          '+${dayBookings.length - 2}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BookingEventChip extends StatelessWidget {
  const _BookingEventChip({required this.booking, required this.state});
  final Booking booking;
  final OperationsState state;

  @override
  Widget build(BuildContext context) {
    final machineNames = booking.machineIds
        .map(
          (id) =>
              state.machines
                  .where((machine) => machine.id == id)
                  .map((machine) => machine.reference)
                  .firstOrNull ??
              'Máquina',
        )
        .join(', ');
    final customer = booking.customerNameSnapshot.isEmpty
        ? state.customers
                  .where((item) => item.id == booking.customerId)
                  .map((item) => item.name)
                  .firstOrNull ??
              'Cliente'
        : booking.customerNameSnapshot;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _bookingColor(booking.status).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        '$machineNames\n$customer',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: _bookingColor(booking.status),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

DateTime _weekStart(DateTime day) {
  final date = DateUtils.dateOnly(day);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}

String _weekDay(DateTime day) =>
    const ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'][day.weekday - 1];

bool _overlapsDay(Booking booking, DateTime day) {
  final start = DateUtils.dateOnly(day);
  final end = start.add(const Duration(days: 1));
  return booking.startsAt.isBefore(end) && booking.endsAt.isAfter(start);
}

bool _overlapsSlot(Booking booking, DateTime day, _HalfDay slot) {
  final start = _slotStartsAt(day, slot);
  final end = start.add(const Duration(hours: 12));
  return booking.startsAt.isBefore(end) && booking.endsAt.isAfter(start);
}

DateTime _slotStartsAt(DateTime day, _HalfDay slot) =>
    DateTime(day.year, day.month, day.day, slot == _HalfDay.morning ? 0 : 12);

bool _isContiguousHalfDaySelection(Iterable<DateTime> slots) {
  final ordered = slots.toList()..sort();
  if (ordered.isEmpty) return false;
  for (var index = 1; index < ordered.length; index++) {
    if (ordered[index].difference(ordered[index - 1]) !=
        const Duration(hours: 12)) {
      return false;
    }
  }
  return true;
}

String _calendarPeriodLabel(DateTimeRange period) {
  final halfDays = period.duration.inHours ~/ 12;
  final start = period.start;
  final end = period.end;
  final startLabel = '${_date(start)} · ${start.hour == 0 ? 'Manhã' : 'Tarde'}';
  final finalSlotStart = end.subtract(const Duration(hours: 12));
  final endLabel =
      '${_date(finalSlotStart)} · ${finalSlotStart.hour == 0 ? 'Manhã' : 'Tarde'}';
  return halfDays == 1 ? startLabel : '$startLabel até $endLabel';
}

Color _bookingColor(BookingStatus status) => switch (status) {
  BookingStatus.request => Colors.blueGrey,
  BookingStatus.proposalSent => Colors.blue,
  BookingStatus.confirmed => Colors.orange.shade800,
  BookingStatus.rented => Colors.deepPurple,
  BookingStatus.completed => Colors.green.shade700,
  BookingStatus.cancelled => Colors.red.shade700,
};

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

Future<bool> _showCalendarBookingConfirmation(
  BuildContext context,
  WidgetRef ref, {
  required Machine machine,
  required DateTime startsAt,
  required DateTime endsAt,
  String? responsibleId,
}) async {
  final state = ref.read(operationsProvider);
  if (state.customers.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Regista primeiro o cliente da reserva.')),
    );
    return false;
  }
  var customerId = state.customers.first.id;
  var status = BookingStatus.request;
  final expectedValue = TextEditingController();
  final notes = TextEditingController();
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Confirmar reserva'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.precision_manufacturing_outlined),
                title: Text('${machine.name} · ${machine.reference}'),
                subtitle: Text(
                  _calendarPeriodLabel(
                    DateTimeRange(start: startsAt, end: endsAt),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: customerId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Cliente'),
                items: state.customers
                    .map(
                      (customer) => DropdownMenuItem(
                        value: customer.id,
                        child: Text(
                          '${customer.name}${customer.phone.isEmpty ? '' : ' · ${customer.phone}'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setDialogState(() => customerId = value!),
              ),
              DropdownButtonFormField<BookingStatus>(
                value: status,
                decoration: const InputDecoration(labelText: 'Estado inicial'),
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final cents =
                  ((double.tryParse(expectedValue.text.replaceAll(',', '.')) ??
                              0) *
                          100)
                      .round();
              final conflict = ref
                  .read(operationsProvider.notifier)
                  .addBooking(
                    Booking(
                      id: 'b${DateTime.now().microsecondsSinceEpoch}',
                      customerId: customerId,
                      machineIds: [machine.id],
                      startsAt: startsAt,
                      endsAt: endsAt,
                      status: status,
                      expectedValueCents: cents > 0 ? cents : null,
                      collaboratorResponsibleId: responsibleId,
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
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Gravar reserva'),
          ),
        ],
      ),
    ),
  );
  expectedValue.dispose();
  notes.dispose();
  return saved ?? false;
}

/// Abre a marcação operacional usada também pela área do colaborador.
///
/// As opções de agenda (data e período) ficam privadas a este ecrã, para não
/// expor tipos internos como parte da API partilhada com os restantes fluxos.
Future<void> showBookingForm(
  BuildContext context,
  WidgetRef ref, {
  String? responsibleId,
}) => _showBookingForm(context, ref, responsibleId: responsibleId);

Future<void> _showBookingForm(
  BuildContext context,
  WidgetRef ref, {
  String? responsibleId,
  DateTime? initialDate,
  _BookingDuration? initialDuration,
  _HalfDay? initialHalfDay,
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
  var startDate = DateUtils.dateOnly(
    initialDate ?? DateTime.now().add(const Duration(days: 1)),
  );
  var endDate = startDate;
  var duration = initialDuration ?? _BookingDuration.halfDay;
  var halfDay = initialHalfDay ?? _HalfDay.morning;
  String? collaboratorId = responsibleId;
  final expectedValue = TextEditingController();
  final notes = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final startsAt = _bookingStartsAt(startDate, duration, halfDay);
        final endsAt = _bookingEndsAt(endDate, duration, halfDay);
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
                  DropdownButtonFormField<_BookingDuration>(
                    value: duration,
                    decoration: const InputDecoration(labelText: 'Duração'),
                    items: const [
                      DropdownMenuItem(
                        value: _BookingDuration.halfDay,
                        child: Text('Meio dia'),
                      ),
                      DropdownMenuItem(
                        value: _BookingDuration.fullDay,
                        child: Text('Dia inteiro'),
                      ),
                      DropdownMenuItem(
                        value: _BookingDuration.multipleDays,
                        child: Text('Vários dias seguidos'),
                      ),
                    ],
                    onChanged: (value) => setDialogState(() {
                      duration = value!;
                      if (duration != _BookingDuration.multipleDays) {
                        endDate = startDate;
                      }
                    }),
                  ),
                  if (duration == _BookingDuration.halfDay)
                    DropdownButtonFormField<_HalfDay>(
                      value: halfDay,
                      decoration: const InputDecoration(labelText: 'Período'),
                      items: const [
                        DropdownMenuItem(
                          value: _HalfDay.morning,
                          child: Text('Manhã'),
                        ),
                        DropdownMenuItem(
                          value: _HalfDay.afternoon,
                          child: Text('Tarde'),
                        ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => halfDay = value!),
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Período'),
                    subtitle: Text(
                      _bookingDatesLabel(startDate, endDate, duration, halfDay),
                    ),
                    trailing: const Icon(Icons.date_range_outlined),
                    onTap: () async {
                      if (duration == _BookingDuration.multipleDays) {
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 1),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 730),
                          ),
                          initialDateRange: DateTimeRange(
                            start: startDate,
                            end: endDate,
                          ),
                        );
                        if (range == null) return;
                        setDialogState(() {
                          startDate = DateUtils.dateOnly(range.start);
                          endDate = DateUtils.dateOnly(range.end);
                        });
                        return;
                      }
                      final date = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 1),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                        initialDate: startDate,
                      );
                      if (date == null) return;
                      setDialogState(() {
                        startDate = DateUtils.dateOnly(date);
                        endDate = startDate;
                      });
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
                  if (responsibleId == null)
                    DropdownButtonFormField<String?>(
                      value: collaboratorId,
                      decoration: const InputDecoration(
                        labelText: 'Responsável',
                      ),
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
                    )
                  else
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline),
                      title: const Text('Registada por'),
                      subtitle: Text(
                        state.collaborators
                                .where(
                                  (collaborator) =>
                                      collaborator.id == responsibleId,
                                )
                                .map((collaborator) => collaborator.name)
                                .firstOrNull ??
                            'Colaborador',
                      ),
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
                      // addBooking valida duração mínima, máquinas por
                      // identificar e máquinas paradas com ArgumentError. Sem
                      // este try a excepção subia por tratar e rebentava o ecrã.
                      final BookingConflict? conflict;
                      try {
                        conflict = ref
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
                      } on ArgumentError catch (error) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${error.message}')),
                        );
                        return;
                      }
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

enum _BookingDuration { halfDay, fullDay, multipleDays }

enum _HalfDay { morning, afternoon }

DateTime _bookingStartsAt(
  DateTime day,
  _BookingDuration duration,
  _HalfDay halfDay,
) => switch (duration) {
  _BookingDuration.halfDay when halfDay == _HalfDay.afternoon => DateTime(
    day.year,
    day.month,
    day.day,
    12,
  ),
  _ => DateTime(day.year, day.month, day.day),
};

DateTime _bookingEndsAt(
  DateTime endDay,
  _BookingDuration duration,
  _HalfDay halfDay,
) => switch (duration) {
  _BookingDuration.halfDay when halfDay == _HalfDay.morning => DateTime(
    endDay.year,
    endDay.month,
    endDay.day,
    12,
  ),
  _ => DateTime(endDay.year, endDay.month, endDay.day + 1),
};

String _bookingDatesLabel(
  DateTime start,
  DateTime end,
  _BookingDuration duration,
  _HalfDay halfDay,
) {
  final dates = duration == _BookingDuration.multipleDays
      ? '${_date(start)} a ${_date(end)}'
      : _date(start);
  final detail = switch (duration) {
    _BookingDuration.halfDay => halfDay == _HalfDay.morning ? 'Manhã' : 'Tarde',
    _BookingDuration.fullDay => 'Dia inteiro',
    _BookingDuration.multipleDays => 'Dias seguidos',
  };
  return '$dates · $detail';
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
  // Mantido no construtor para não partir os call sites, mas o header foi
  // removido: era só rótulo informativo (o item da sidebar já mostra em que
  // ecrã se está, com border laranja à esquerda) e ocupava ~60 dp de altura
  // que agora entram no conteúdo — sobretudo útil em landscape mobile.
  final String title;
  final Widget action, child;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Só o action (botão de acção principal do ecrã), alinhado à direita.
          Align(alignment: Alignment.centerRight, child: action),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    ),
  );
}
