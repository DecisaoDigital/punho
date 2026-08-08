import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/finance/regime_fiscal.dart';
import '../../../core/format/campos.dart';
import '../../../core/layout/margens_do_canvas.dart';
import '../../../core/finance/retencao_irs.dart';
import '../../../core/layout/ecra_de_formulario.dart';
import '../../../core/operations/kpis.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../data/repositories/operation_repository.dart';
import '../../../domain/models/finance.dart';
import '../../../domain/models/workforce.dart';
import '../../auth/subscricao_providers.dart';
import 'ficha_fiscal_form.dart';

/// Erro de leitura para um campo de euros opcional: `null` quando o campo
/// está vazio (o valor é mesmo desconhecido, fica "por apurar") ou legível;
/// mensagem quando tem texto que não se lê como euro — "1.500.00" com dois
/// pontos, letras, o que for. Nunca se grava um zero calado por um texto que
/// não se conseguiu ler: se parte, tem de partir com estrondo.
String? _erroDeValorOpcional(String rotulo, String textoEscrito) {
  final texto = textoEscrito.trim();
  if (texto.isEmpty) return null;
  return centsDeTexto(textoEscrito) == null
      ? 'Não consigo ler $rotulo: "$texto" — escreve por exemplo 1.500,00.'
      : null;
}

/// "N vagas contratadas", com o singular tratado: "1 vaga contratada" e não
/// "1 vagas contratadas".
String _vagasContratadas(int limite) =>
    limite == 1 ? '1 vaga contratada' : '$limite vagas contratadas';

/// Frase sobre as vagas de colaboradores para o cabeçalho do ecrã.
///
/// Quando a subscrição no servidor desce abaixo de quem já está activo — o
/// caso real que motivou isto: limite 1, três colaboradores já activos — "3
/// colaboradores ativos de 1 vaga contratada" lê-se como um erro de gramática,
/// não como um aviso. Ninguém é apagado nesse caso (só se recusam novos, em
/// [OperationsController.saveCollaborator]), por isso a frase diz isso mesmo:
/// que não há vagas livres, e não finge que os números batem certo.
String mensagemVagasDeColaboradores(int ativos, int limite) {
  if (ativos > limite) {
    return '$ativos colaboradores ativos, sem vagas livres — a subscrição '
        'cobre ${_vagasContratadas(limite)}. Os já ativos mantêm-se; fala '
        'com o suporte para ajustar a subscrição antes de adicionar mais.';
  }
  return '$ativos colaboradores ativos de ${_vagasContratadas(limite)}';
}

/// Aviso mostrado no formulário depois de gravar um colaborador que deixou a
/// empresa acima das vagas autorizadas pelo plano.
///
/// Não bloqueia nada — decisão de 2026-08-02: a ficha já está gravada quando
/// isto aparece. Só avisa que o colaborador não ganha acesso à app sem uma
/// aprovação explícita do gestor da subscrição no Control.
String _avisoDeLimiteExcedido(int ativos, int limite) {
  final vagas = limite == 1 ? '1 vaga autorizada' : '$limite vagas autorizadas';
  return '$ativos colaboradores ativos, $vagas pelo plano — este colaborador '
      'consegue cadastrar-se, mas só acede depois de o gestor da subscrição '
      'autorizar.';
}

class CollaboratorsPage extends ConsumerWidget {
  const CollaboratorsPage({super.key, this.agora});

  /// Injectável para os testes fixarem o mês das vendas.
  final DateTime? agora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(operationsProvider);
    // O limite efectivo: o da subscrição no servidor quando dá para o ler,
    // senão o local — ver `limiteColaboradoresEfetivoProvider`.
    final limite = ref.watch(limiteColaboradoresEfetivoProvider);
    final mes = agora ?? DateTime.now();
    // Arquivados fora da lista: eliminar tem de fazer a linha desaparecer, ou
    // não se acredita que tenha eliminado.
    final colaboradores = s.collaborators.where((c) => !c.archived).toList();
    final semVagasLivres = s.activeCollaborators > limite;
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
              mensagemVagasDeColaboradores(s.activeCollaborators, limite),
              // Cor de aviso só quando não há vagas livres — tal como o
              // `aviso` de `EcraDeFormulario`. Sem isto, o caso raro (mas
              // real) de a subscrição ter descido abaixo de quem já está
              // activo lê-se como texto normal, e passa despercebido.
              style: semVagasLivres
                  ? TextStyle(color: Theme.of(context).colorScheme.error)
                  : null,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _formularioDeColaborador(context, ref),
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
                        onTap: () => _formularioDeColaborador(context, ref, c),
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
                                  _formularioDeColaborador(context, ref, c),
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

/// Abre o formulário do colaborador em ecrã completo.
///
/// Não se sai por engano — quem tem texto escrito tem de confirmar. Era o que
/// o `barrierDismissible: false` fazia no diálogo, agora sem o preço de um
/// formulário que não cabia no ecrã deitado.
Future<void> _formularioDeColaborador(
  BuildContext context,
  WidgetRef ref, [
  Collaborator? current,
]) => abrirFormulario<void>(
  context,
  (_) => _FormularioDeColaborador(
    notifier: ref.read(operationsProvider.notifier),
    // Só é preciso para reler os activos depois de gravar e montar o aviso de
    // limite excedido: `notifier.state` não é acessível fora do próprio
    // `Notifier` (mesma razão do `repository` em `_FormularioDeCliente`, em
    // `operational_pages.dart`).
    repository: ref.read(operationRepositoryProvider),
    // O regime vem da forma jurídica da empresa, não de um valor assumido
    // (Decisão 1). É ele que decide se há estimativa e qual.
    regime: regimeDaFormaJuridica(ref.read(operationsProvider).legalForm),
    // `.read` e não `.watch`: o diálogo é um formulário de um só uso, tal
    // como o `regime` acima — não precisa de se recompor se a subscrição
    // mudar a meio do preenchimento.
    limiteColaboradoresAtivos: ref.read(limiteColaboradoresEfetivoProvider),
    current: current,
  ),
);

class _FormularioDeColaborador extends StatefulWidget {
  const _FormularioDeColaborador({
    required this.notifier,
    required this.repository,
    required this.regime,
    required this.limiteColaboradoresAtivos,
    this.current,
  });

  final OperationsController notifier;
  final OperationRepository repository;
  final int limiteColaboradoresAtivos;
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

  /// Mensagem mostrada **dentro** do diálogo e não num `SnackBar`.
  ///
  /// Num telemóvel deitado com o teclado aberto, o `SnackBar` nasce por baixo
  /// do teclado — apanhado no Redmi Note 10 Pro. Servia para a recusa por
  /// exceder vagas; desde a decisão de 2026-08-02 essa recusa não existe, e o
  /// campo passou a mostrar validação (nome em falta) e o aviso não
  /// bloqueante de limite excedido, que fica visível porque o diálogo só
  /// fecha depois de o gestor ler.
  String? erro;

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
    final cents = centsDeTexto(cost.text);
    if (cents == null || cents <= 0) return null;
    return frequency == CostFrequency.monthly
        ? cents
        // O custo semanal mensaliza-se para a estimativa: as taxas são mensais.
        : (cents * 52 / 12).round();
  }

  @override
  Widget build(BuildContext context) {
    return EcraDeFormulario(
      // "Adicionar" em vez de "Novo": deixa claro que é acção pendente, não
      // confirmação de que já foi criado.
      titulo: current == null ? 'Adicionar colaborador' : 'Editar colaborador',
      campos: [
        // O vínculo primeiro e a ocupar a linha toda: é ele que decide que
        // campos a ficha fiscal mostra a seguir.
        CampoLargo(
          _EscolhaDeVinculo(
            valor: vinculo,
            aoEscolher: (v) => setState(() => vinculo = v),
          ),
        ),
        CampoDeTexto(
          controlador: name,
          rotulo: 'Nome',
          autofocus: true,
          capitalizacao: TextCapitalization.words,
        ),
        CampoDeTexto(
          controlador: cost,
          rotulo: 'Custo estimado para a empresa (€)',
          // `number` seco abre o teclado de inteiros do Android — sem vírgula
          // nenhuma. O campo lê cêntimos e o teclado não deixava escrevê-los,
          // e quem estava a preencher não tinha como perceber que o problema
          // era o teclado e não o que tinha escrito.
          teclado: const TextInputType.numberWithOptions(decimal: true),
          // Recalcula a estimativa a cada tecla: o gestor vê o custo real
          // subir enquanto escreve o vencimento, que é o ponto todo.
          aoMudar: (_) => setState(() {}),
        ),
        CampoDeTexto(
          controlador: phone,
          rotulo: 'Telemóvel',
          teclado: TextInputType.phone,
        ),
        CampoDeTexto(controlador: role, rotulo: 'Função'),
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
        CampoDeTexto(
          controlador: hours,
          rotulo: 'Horas semanais previstas',
          ajuda: 'Usadas para calcular o custo/hora estimado.',
          teclado: TextInputType.number,
        ),
        // A ficha fiscal traz os seus próprios campos e eles entram na mesma
        // cadeia de foco: quem se inscreve é o campo, não quem o arruma.
        CampoLargo(
          FichaFiscalColaboradorForm(
            tipo: vinculo,
            controladores: ficha,
            estadoCivil: estadoCivil,
            aoMudarEstadoCivil: (v) => setState(() => estadoCivil = v),
          ),
        ),
        CampoLargo(
          BlocoDeEstimativa(
            regime: widget.regime,
            tipo: vinculo,
            estadoCivil: estadoCivil,
            dependentes: int.tryParse(ficha.dependentes.text.trim()) ?? 0,
            brutoMensalCents: _brutoCents,
          ),
        ),
      ],
      aviso: erro,
      aoGuardar: () {
        // Validação: nome é obrigatório. Sem isto, um tap por engano criava um
        // colaborador anónimo silenciosamente — o Cesar apanhou este bug no
        // smoke da v0.0.4.
        if (name.text.trim().isEmpty) {
          setState(() => erro = 'Indica o nome do colaborador.');
          return;
        }
        // Custo: campo opcional (fica "por apurar" em branco), mas texto que
        // não se lê como euro recusa a gravação em vez de virar zero calado —
        // era exactamente isto que `(double.tryParse(...) ?? 0)` fazia com
        // "1.500,00" (separador de milhar): lia até ao primeiro erro e
        // inventava zero.
        final erroDeCusto = _erroDeValorOpcional('o custo estimado', cost.text);
        if (erroDeCusto != null) {
          setState(() => erro = erroDeCusto);
          return;
        }
        final anterior = current;
        final custoCents = centsDeTexto(cost.text);
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
        // Grava sempre — a decisão de 2026-08-02 tirou a recusa por vagas.
        // O que resta é avisar, sem bloquear: se isto deixou a empresa acima
        // do autorizado, o diálogo fica aberto com o aviso em vez de fechar,
        // para o gestor não o perder por trás de um `SnackBar`. Lê-se do
        // repositório e não de `notifier.state` (inacessível fora do
        // `Notifier`) — mesma contagem de `OperationsState.activeCollaborators`.
        final ativos = widget.repository.collaborators
            .where((c) => !c.archived && c.status == CollaboratorStatus.active)
            .length;
        if (ativos > widget.limiteColaboradoresAtivos) {
          setState(
            () => erro = _avisoDeLimiteExcedido(
              ativos,
              widget.limiteColaboradoresAtivos,
            ),
          );
          return;
        }
        Navigator.pop(context);
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
    // Arquivados fora da lista e do custo da frota: eliminar tem de fazer a
    // linha (e o número) desaparecer, ou não se acredita que eliminou — mesma
    // regra das outras entidades.
    final veiculos = s.vehicles.where((v) => !v.archived).toList();
    // Soma-se o que se sabe e diz-se quantos ficaram por apurar. Esconder o
    // total até estar tudo preenchido seria pior: quem tem nove veículos
    // completos e um por declarar ficava sem número nenhum.
    final custos = veiculos.map(monthlyFleetCost).toList();
    final total = custos.whereType<int>().fold(0, (sum, c) => sum + c);
    final porApurar = custos.where((c) => c == null).length;
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
              veiculos.isEmpty
                  ? 'Frota declarada, veículos por identificar'
                  : 'Custo mensal estimado da frota: '
                        '${(total / 100).toStringAsFixed(2)} €'
                        '${porApurar == 0 ? '' : porApurar == 1 ? ' · 1 veículo por apurar' : ' · $porApurar veículos por apurar'}',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _formularioDeVeiculo(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar veículo'),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final v in veiculos)
                    Card(
                      child: ListTile(
                        // Tocar na linha edita, como nos colaboradores: era o
                        // gesto que não fazia nada antes desta correcção.
                        onTap: () => _formularioDeVeiculo(context, ref, v),
                        title: Text(v.plate),
                        subtitle: Builder(
                          builder: (_) {
                            // "por apurar" e não 0 €, que se leria como "não
                            // custa nada" — mesmo padrão da ficha fiscal.
                            final custo = monthlyFleetCost(v);
                            return Text(
                              custo == null
                                  ? '${v.type} · Custo: por apurar'
                                  : '${v.type} · Custo: '
                                        '${(custo / 100).toStringAsFixed(2)} €/mês',
                            );
                          },
                        ),
                        trailing: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Editar veículo',
                              onPressed: () =>
                                  _formularioDeVeiculo(context, ref, v),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Eliminar veículo',
                              onPressed: () =>
                                  _confirmarEliminarVeiculo(context, ref, v),
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

/// Eliminar com 6 segundos para anular, como nas máquinas e nos colaboradores.
Future<void> _confirmarEliminarVeiculo(
  BuildContext context,
  WidgetRef ref,
  Vehicle v,
) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Eliminar ${v.plate}?'),
      content: const Text(
        'O veículo sai da lista. As despesas já associadas a ele não se '
        'perdem.',
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
  ref.read(operationsProvider.notifier).archiveVehicle(v.id);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('${v.plate} eliminado.'),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: 'Anular',
        onPressed: () =>
            ref.read(operationsProvider.notifier).unarchiveVehicle(v.id),
      ),
    ),
  );
}

/// Abre o formulário do veículo em ecrã completo.
///
/// Era um `showDialog`, e em paisagem com o teclado aberto não se via um único
/// campo — só o título e o botão *Guardar*. Os quatro defeitos que o Cesar
/// apanhou no smoke da v0.0.4 continuam resolvidos por outra via: não se sai
/// por engano (é preciso confirmar), o título diz "Adicionar" e não "Novo",
/// valida antes de gravar e o cursor nasce na matrícula.
Future<void> _formularioDeVeiculo(
  BuildContext context,
  WidgetRef ref, [
  Vehicle? current,
]) => abrirFormulario<void>(
  context,
  (_) => _FormularioDeVeiculo(
    notifier: ref.read(operationsProvider.notifier),
    current: current,
  ),
);

class _FormularioDeVeiculo extends StatefulWidget {
  const _FormularioDeVeiculo({required this.notifier, this.current});

  final OperationsController notifier;
  final Vehicle? current;

  @override
  State<_FormularioDeVeiculo> createState() => _FormularioDeVeiculoState();
}

class _FormularioDeVeiculoState extends State<_FormularioDeVeiculo> {
  late final Vehicle? current = widget.current;
  late final plate = TextEditingController(text: current?.plate);
  late final type = TextEditingController(text: current?.type);
  late final alias = TextEditingController(text: current?.alias);
  late final monthlyPayment = TextEditingController(
    text: textoDeCents(current?.monthlyPaymentCents),
  );
  late final paymentDay = TextEditingController(
    text: current?.paymentDayOfMonth?.toString() ?? '',
  );
  late final insurance = TextEditingController(
    text: textoDeCents(current?.insuranceCents),
  );
  late var insuranceFrequency =
      current?.insuranceFrequency ?? InsuranceFrequency.annual;
  late final maintenance = TextEditingController(
    text: textoDeCents(current?.maintenanceCents),
  );

  /// Mensagem mostrada dentro do diálogo, como no de colaborador — não num
  /// `SnackBar`, que nasce debaixo do teclado num telemóvel deitado.
  String? erro;

  @override
  void dispose() {
    plate.dispose();
    type.dispose();
    alias.dispose();
    monthlyPayment.dispose();
    paymentDay.dispose();
    insurance.dispose();
    maintenance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EcraDeFormulario(
      titulo: current == null ? 'Adicionar veículo' : 'Editar veículo',
      campos: [
        CampoDeTexto(
          controlador: plate,
          rotulo: 'Matrícula',
          autofocus: true,
          // Matrículas escrevem-se em maiúsculas.
          capitalizacao: TextCapitalization.characters,
        ),
        CampoDeTexto(controlador: type, rotulo: 'Tipo'),
        CampoDeTexto(controlador: alias, rotulo: 'Nome / identificação'),
        CampoDeTexto(
          controlador: monthlyPayment,
          rotulo: 'Prestação mensal (€)',
          teclado: const TextInputType.numberWithOptions(decimal: true),
        ),
        // O dia importa tanto como o valor: é o que separa "já saiu da conta"
        // de "ainda vai sair", e sem ele o painel não sabe dizer nenhuma das
        // duas coisas. Em branco, a prestação conta repartida pelo mês.
        CampoDeTexto(
          controlador: paymentDay,
          rotulo: 'Dia do débito',
          ajuda: 'Dia do mês em que a prestação sai da conta',
          teclado: TextInputType.number,
        ),
        CampoDeTexto(
          controlador: insurance,
          rotulo: 'Seguro (€)',
          teclado: const TextInputType.numberWithOptions(decimal: true),
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
        CampoDeTexto(
          controlador: maintenance,
          rotulo: 'Manutenção prevista — valor anual (€)',
          teclado: const TextInputType.numberWithOptions(decimal: true),
        ),
      ],
      aviso: erro,
      aoGuardar: () {
        // Sem matrícula o veículo não se identifica. Não se valida o formato
        // AA-11-BB: pode ser matrícula estrangeira ou histórica.
        final matricula = plate.text.trim();
        if (matricula.isEmpty) {
          setState(() => erro = 'Indica a matrícula do veículo.');
          return;
        }
        // Prestação, seguro e manutenção são opcionais (ficam "por apurar" em
        // branco), mas texto ilegível — "1.500.00" com dois pontos, letras —
        // recusa a gravação em vez de virar zero calado.
        final erroDaPrestacao = _erroDeValorOpcional(
          'a prestação mensal',
          monthlyPayment.text,
        );
        final erroDoSeguro = _erroDeValorOpcional('o seguro', insurance.text);
        final erroDaManutencao = _erroDeValorOpcional(
          'a manutenção prevista',
          maintenance.text,
        );
        final erroDeValor = erroDaPrestacao ?? erroDoSeguro ?? erroDaManutencao;
        if (erroDeValor != null) {
          setState(() => erro = erroDeValor);
          return;
        }
        // Um dia fora de 1..31 não se aceita calado: guardá-lo como `null`
        // fazia a prestação desaparecer da conta das saídas sem ninguém saber
        // porquê.
        final diaEscrito = paymentDay.text.trim();
        final dia = diaEscrito.isEmpty
            ? null
            : diaDoMesValido(int.tryParse(diaEscrito));
        if (diaEscrito.isNotEmpty && dia == null) {
          setState(
            () => erro = 'O dia do débito tem de ser um número entre 1 e 31.',
          );
          return;
        }
        final anterior = current;
        final prestacaoCents = centsDeTexto(monthlyPayment.text);
        final seguroCents = centsDeTexto(insurance.text);
        final manutencaoCents = centsDeTexto(maintenance.text);
        // A editar mantém-se o mesmo id e passa-se por copyWith: construir um
        // Vehicle novo criava um segundo registo e deixava o antigo na lista.
        widget.notifier.saveVehicle(
          anterior != null
              ? anterior.copyWith(
                  plate: matricula,
                  type: type.text,
                  alias: alias.text.trim().isEmpty ? null : alias.text.trim(),
                  monthlyPaymentCents: prestacaoCents,
                  paymentDayOfMonth: dia,
                  insuranceCents: seguroCents,
                  insuranceFrequency: insurance.text.trim().isEmpty
                      ? null
                      : insuranceFrequency,
                  maintenanceCents: manutencaoCents,
                )
              : Vehicle(
                  id: 'v${DateTime.now().microsecondsSinceEpoch}',
                  plate: matricula,
                  type: type.text,
                  status: VehicleStatus.active,
                  alias: alias.text.trim().isEmpty ? null : alias.text.trim(),
                  monthlyPaymentCents: prestacaoCents,
                  paymentDayOfMonth: dia,
                  insuranceCents: seguroCents,
                  insuranceFrequency: insurance.text.trim().isEmpty
                      ? null
                      : insuranceFrequency,
                  maintenanceCents: manutencaoCents,
                ),
        );
        Navigator.pop(context);
      },
    );
  }
}
