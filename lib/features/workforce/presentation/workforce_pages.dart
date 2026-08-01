import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/finance/regime_fiscal.dart';
import '../../../core/layout/margens_do_canvas.dart';
import '../../../core/finance/retencao_irs.dart';
import '../../../core/layout/dialogo_de_formulario.dart';
import '../../../core/operations/kpis.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../domain/models/workforce.dart';
import 'ficha_fiscal_form.dart';

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
        // Começa por texto: margem vertical inteira. Ver [MargensDoCanvas].
        padding: const EdgeInsets.fromLTRB(
          MargensDoCanvas.lateral,
          MargensDoCanvas.vertical,
          MargensDoCanvas.lateral,
          MargensDoCanvas.vertical,
        ),
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
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                c.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_dadoEmFalta(c) != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _ChipDeFalta(texto: _dadoEmFalta(c)!),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          '${_subtitulo(c, s, mes)}\n'
                          '${_linhaDoVinculo(c, regimeDaFormaJuridica(s.legalForm))}',
                        ),
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
                              onPressed: () => _confirmarEliminarColaborador(
                                context,
                                ref,
                                c,
                              ),
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
    // O regime vem da forma jurídica da empresa, não de um valor assumido
    // (Decisão 1). É ele que decide se há estimativa e qual.
    regime: regimeDaFormaJuridica(ref.read(operationsProvider).legalForm),
    current: current,
  ),
);

class _FormularioDeColaborador extends StatefulWidget {
  const _FormularioDeColaborador({
    required this.notifier,
    required this.regime,
    this.current,
  });

  final OperationsController notifier;
  final RegimeFiscal regime;
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
  late var vinculo = current?.employmentType ?? EmploymentType.contrato;
  late var estadoCivil = current?.maritalStatus ?? MaritalStatus.unmarried;
  late final ficha = ControladoresDaFicha(de: current);

  @override
  void dispose() {
    name.dispose();
    cost.dispose();
    hours.dispose();
    phone.dispose();
    role.dispose();
    ficha.dispose();
    super.dispose();
  }

  /// O bruto escrito no campo, em cêntimos. `null` enquanto estiver vazio — a
  /// estimativa mostra "por apurar" em vez de zeros.
  int? get _brutoCents {
    final valor = double.tryParse(cost.text.replaceAll(',', '.'));
    if (valor == null || valor <= 0) return null;
    return frequency == CostFrequency.monthly
        ? (valor * 100).round()
        // O custo semanal mensaliza-se para a estimativa: as taxas são mensais.
        : (valor * 100 * 52 / 12).round();
  }

  @override
  Widget build(BuildContext context) {
    return DialogoDeFormulario(
      // "Adicionar" em vez de "Novo": deixa claro que é acção pendente, não
      // confirmação de que já foi criado.
      titulo: current == null ? 'Adicionar colaborador' : 'Editar colaborador',
      larguraMaxima: 920,
      corpo: LayoutBuilder(
        builder: (context, constraints) {
          final identificacao = <Widget>[
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            TextField(
              controller: cost,
              keyboardType: TextInputType.number,
              // Recalcula a estimativa a cada tecla: o gestor vê o custo real
              // subir enquanto escreve o vencimento, que é o ponto todo.
              onChanged: (_) => setState(() {}),
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
              initialValue: frequency,
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
          ];
          final fiscal = <Widget>[
            FichaFiscalColaboradorForm(
              tipo: vinculo,
              controladores: ficha,
              estadoCivil: estadoCivil,
              aoMudarEstadoCivil: (v) => setState(() => estadoCivil = v),
            ),
            const SizedBox(height: 16),
            BlocoDeEstimativa(
              regime: widget.regime,
              tipo: vinculo,
              estadoCivil: estadoCivil,
              dependentes: int.tryParse(ficha.dependentes.text.trim()) ?? 0,
              brutoMensalCents: _brutoCents,
            ),
          ];

          final duasColunas = constraints.maxWidth >= 640;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _EscolhaDeVinculo(
                valor: vinculo,
                aoEscolher: (v) => setState(() => vinculo = v),
              ),
              const SizedBox(height: 12),
              if (!duasColunas) ...[
                ...identificacao,
                const SizedBox(height: 16),
                ...fiscal,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: identificacao,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: fiscal,
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
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
        // Só se guarda o que o vínculo usa. Trocar de contrato para recibos
        // verdes limpa o NISS de facto — é para isso que o `copyWith` tem
        // sentinela em vez de `??`. Guardar um NISS num prestador de serviços
        // seria guardar um dado que ninguém pediu e que não se pode justificar.
        final campos = camposDaFicha(vinculo);
        final niss = campos.contains(CampoDaFichaFiscal.niss)
            ? _semVazio(ficha.niss.text)
            : null;
        final nif = campos.contains(CampoDaFichaFiscal.nif)
            ? _semVazio(ficha.nif.text)
            : null;
        final dependentes = campos.contains(CampoDaFichaFiscal.dependentes)
            ? int.tryParse(ficha.dependentes.text.trim()) ?? 0
            : 0;
        final estado = campos.contains(CampoDaFichaFiscal.estadoCivil)
            ? estadoCivil
            : MaritalStatus.unmarried;
        try {
          // A editar mantém-se o mesmo id e passa-se por copyWith: construir um
          // Collaborator novo criava um segundo registo e deixava o antigo na
          // lista, além de perder as notas que este diálogo não mostra.
          widget.notifier.saveCollaborator(
            anterior != null
                ? anterior.copyWith(
                    name: name.text.trim(),
                    phone: _semVazio(phone.text),
                    role: _semVazio(role.text),
                    costFrequency: frequency,
                    costCents: custoCents,
                    schedule: horario,
                    employmentType: vinculo,
                    socialSecurityNumber: niss,
                    taxId: nif,
                    maritalStatus: estado,
                    dependents: dependentes,
                  )
                : Collaborator(
                    id: 'co${DateTime.now().microsecondsSinceEpoch}',
                    name: name.text.trim(),
                    status: CollaboratorStatus.active,
                    phone: _semVazio(phone.text),
                    role: _semVazio(role.text),
                    costFrequency: frequency,
                    costCents: custoCents,
                    schedule: horario,
                    employmentType: vinculo,
                    socialSecurityNumber: niss,
                    taxId: nif,
                    maritalStatus: estado,
                    dependents: dependentes,
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

/// O dado que falta na ficha, ou `null` quando está completa.
///
/// Um por vínculo, porque é um por vínculo que interessa: sem NISS não se
/// declara um contrato, sem NIF não se lança a despesa de um prestador. Não se
/// bloqueia a gravação por isto — a app aceita dados parciais e sinaliza.
String? _dadoEmFalta(Collaborator c) => switch (c.employmentType) {
  EmploymentType.contrato when (c.socialSecurityNumber ?? '').trim().isEmpty =>
    'NISS em falta',
  EmploymentType.recibosVerdes when (c.taxId ?? '').trim().isEmpty =>
    'NIF em falta',
  _ => null,
};

/// Segunda linha do subtítulo: o vínculo e o que ele custa de facto.
String _linhaDoVinculo(Collaborator c, RegimeFiscal regime) {
  final bruto = monthlyCollaboratorCost(c);
  final estimativa = estimarSalarial(
    regime: regime,
    tipo: c.employmentType,
    estado: c.maritalStatus,
    dependentes: c.dependents,
    brutoMensalCents: bruto,
  );
  final partes = <String>[rotuloDeVinculo(c.employmentType)];
  if (c.employmentType == EmploymentType.contrato) {
    partes.add(rotuloDeEstadoCivil(c.maritalStatus));
    if (c.dependents > 0) partes.add('${c.dependents} dep.');
  }
  final custo = estimativa?.custoEmpresaCents;
  partes.add(
    custo == null
        // Sem bruto declarado, ou regime não modelado: não se inventa.
        ? 'custo por apurar'
        : '${c.employmentType == EmploymentType.contrato ? 'custo real' : 'custo'} '
              '${(custo / 100).toStringAsFixed(2)} €/mês',
  );
  return partes.join(' · ');
}

/// Chip âmbar de dado em falta. O mesmo tom do "Por identificar" das máquinas —
/// é a mesma ideia: está registado, falta acabar.
class _ChipDeFalta extends StatelessWidget {
  const _ChipDeFalta({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) => Chip(
    visualDensity: VisualDensity.compact,
    label: Text(texto),
    labelStyle: const TextStyle(fontSize: 11),
    backgroundColor: const Color(0xFFFFF1DA),
    side: BorderSide.none,
  );
}

/// Texto aparado, ou `null` quando não sobra nada.
///
/// Devolver `null` e não `''` é o que permite ao `copyWith` distinguir "apaga
/// isto" de "não sei": uma string vazia gravada é um campo preenchido com nada.
String? _semVazio(String valor) {
  final aparado = valor.trim();
  return aparado.isEmpty ? null : aparado;
}

/// Escolha do vínculo, no topo do diálogo.
///
/// É a primeira pergunta porque é a que decide o resto: o que se pede a seguir,
/// e se há TSU patronal a somar. Trocar de vínculo a meio do preenchimento não
/// perde o que já está escrito — os controladores são os mesmos, só deixam de
/// ser mostrados os campos que aquele vínculo não usa.
///
/// Hit target: o `SegmentedButton` do Material já garante que a área que recebe o
/// toque é a área desenhada — o `Material` pinta e o `InkWell` recebe, com a
/// mesma bounding box. Não se hand-rola nada aqui de propósito; o problema que a
/// auditoria do hit target persegue é o contrário disto (um `Container` colorido
/// com um `InkWell` menor por dentro).
class _EscolhaDeVinculo extends StatelessWidget {
  const _EscolhaDeVinculo({required this.valor, required this.aoEscolher});

  final EmploymentType valor;
  final ValueChanged<EmploymentType> aoEscolher;

  @override
  Widget build(BuildContext context) => SegmentedButton<EmploymentType>(
    segments: EmploymentType.values
        .map(
          (tipo) =>
              ButtonSegment(value: tipo, label: Text(rotuloDeVinculo(tipo))),
        )
        .toList(),
    selected: {valor},
    showSelectedIcon: false,
    onSelectionChanged: (escolha) => aoEscolher(escolha.first),
  );
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
        // Começa por texto: margem vertical inteira. Ver [MargensDoCanvas].
        padding: const EdgeInsets.fromLTRB(
          MargensDoCanvas.lateral,
          MargensDoCanvas.vertical,
          MargensDoCanvas.lateral,
          MargensDoCanvas.vertical,
        ),
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
            initialValue: insuranceFrequency,
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
