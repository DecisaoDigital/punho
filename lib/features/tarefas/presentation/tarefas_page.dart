import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/campos.dart';
import '../../../core/layout/dialogo_de_formulario.dart';
import '../../../core/navigation/app_destination.dart';
import '../../../core/layout/margens_do_canvas.dart';
import '../../../core/navigation/navigation_controller.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../core/theme/punho_theme.dart';
import '../../company/presentation/company_settings_page.dart';
import '../../gestao/presentation/convites_screen.dart';
import '../data/tarefas_service.dart';
import '../domain/tarefa.dart';

/// Tudo o que está por fazer, num sítio só.
class TarefasPage extends ConsumerWidget {
  const TarefasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tarefas = ref.watch(tarefasProvider);
    if (tarefas.isEmpty) return const _SemTarefas();
    return SafeArea(
      child: ListView(
        // Começa por texto: margem vertical inteira. Ver [MargensDoCanvas].
        padding: const EdgeInsets.fromLTRB(
          MargensDoCanvas.lateral,
          MargensDoCanvas.vertical,
          MargensDoCanvas.lateral,
          MargensDoCanvas.vertical,
        ),
        children: [
          Text(
            tarefas.length == 1
                ? '1 tarefa pendente'
                : '${tarefas.length} tarefas pendentes',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Recolhido do que a app já sabe: cobranças, dados por preencher e '
            'conselhos que adiaste.',
          ),
          const SizedBox(height: 20),
          for (final severidade in SeveridadeTarefa.values)
            if (tarefas.any((t) => t.severidade == severidade))
              _Grupo(
                severidade: severidade,
                tarefas: tarefas
                    .where((t) => t.severidade == severidade)
                    .toList(),
              ),
        ],
      ),
    );
  }
}

/// Cor e ícone de cada grupo. Em Flutter nunca se usam emojis — o mockup usava
/// por conveniência do HTML.
({Color cor, IconData icone}) aparenciaDaSeveridade(
  SeveridadeTarefa severidade,
) => switch (severidade) {
  SeveridadeTarefa.urgente => (
    cor: const Color(0xFFE24B4A),
    icone: Icons.warning_amber_rounded,
  ),
  SeveridadeTarefa.aCompletar => (
    cor: PunhoTheme.orange,
    icone: Icons.edit_note_outlined,
  ),
  SeveridadeTarefa.sugestao => (
    cor: const Color(0xFF639922),
    icone: Icons.emoji_objects_outlined,
  ),
};

class _Grupo extends StatelessWidget {
  const _Grupo({required this.severidade, required this.tarefas});
  final SeveridadeTarefa severidade;
  final List<Tarefa> tarefas;

  @override
  Widget build(BuildContext context) {
    final aparencia = aparenciaDaSeveridade(severidade);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(aparencia.icone, size: 18, color: aparencia.cor),
            const SizedBox(width: 8),
            Text(
              severidade.label.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: aparencia.cor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final tarefa in tarefas)
          _LinhaTarefa(tarefa: tarefa, cor: aparencia.cor),
        const SizedBox(height: 22),
      ],
    );
  }
}

class _LinhaTarefa extends ConsumerWidget {
  const _LinhaTarefa({required this.tarefa, required this.cor});
  final Tarefa tarefa;
  final Color cor;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: cor, width: 4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tarefa.titulo,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tarefa.subtitulo,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () => abrirDestinoDaTarefa(
                context,
                ref,
                tarefa.destino,
                referencia: tarefa.referencia,
              ),
              child: Text('${tarefa.cta} →'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Leva a tarefa ao ecrã onde ela se resolve. Os destinos que são áreas da
/// barra lateral trocam de destino em vez de empilhar rotas — assim o
/// utilizador fica onde consegue continuar a trabalhar.
void abrirDestinoDaTarefa(
  BuildContext context,
  WidgetRef ref,
  DestinoTarefa destino, {
  String? referencia,
}) {
  void irPara(AppDestination area) =>
      ref.read(navigationProvider.notifier).goTo(area);
  switch (destino) {
    case DestinoTarefa.definicoesEmpresa:
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const CompanySettingsPage()),
      );
    case DestinoTarefa.facturacaoDoAno:
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DialogoDeFacturacaoDoAno(
          notifier: ref.read(operationsProvider.notifier),
        ),
      );
    case DestinoTarefa.convites:
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          // O código vai à frente para o ecrã destacar a linha: numa lista de
          // dez convites, abrir sem dizer qual não resolve a tarefa.
          builder: (_) => ConvitesScreen(destacarCodigo: referencia),
        ),
      );
    case DestinoTarefa.clientes:
      irPara(AppDestination.clients);
    case DestinoTarefa.maquinas:
      irPara(AppDestination.machines);
    case DestinoTarefa.colaboradores:
      irPara(AppDestination.employees);
    case DestinoTarefa.frota:
      irPara(AppDestination.vehicles);
    case DestinoTarefa.reservas:
      irPara(AppDestination.bookings);
    case DestinoTarefa.financas:
      irPara(AppDestination.finances);
    case DestinoTarefa.painel:
      irPara(AppDestination.management);
  }
}

/// Pergunta directa da faturação deste ano, sem passar pelo formulário
/// inteiro de Dados da Empresa — era só isto que a tarefa precisava.
class _DialogoDeFacturacaoDoAno extends StatefulWidget {
  const _DialogoDeFacturacaoDoAno({required this.notifier});
  final OperationsController notifier;

  @override
  State<_DialogoDeFacturacaoDoAno> createState() =>
      _DialogoDeFacturacaoDoAnoState();
}

class _DialogoDeFacturacaoDoAnoState extends State<_DialogoDeFacturacaoDoAno> {
  final _valor = TextEditingController();
  String? erro;

  @override
  void dispose() {
    _valor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DialogoDeFormulario(
    titulo: 'Faturação deste ano até hoje',
    corpo: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Quanto é que a empresa já faturou este ano, até hoje?'),
        const SizedBox(height: 12),
        TextField(
          controller: _valor,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Faturação deste ano até hoje (€)',
          ),
        ),
      ],
    ),
    aviso: erro,
    aoGuardar: () {
      final cents = centsDeTexto(_valor.text);
      if (cents == null) {
        setState(() => erro = 'Indica um valor em euros.');
        return;
      }
      widget.notifier.updateCompanySettings(revenueThisYearCents: Campo(cents));
      Navigator.pop(context);
    },
  );
}

class _SemTarefas extends StatelessWidget {
  const _SemTarefas();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Nada pendente',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Sem cobranças em atraso, sem dados em falta e sem conselhos '
            'adiados.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
