import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ciclo/proximo_passo.dart';
import '../../../core/format/campos.dart';
import '../../../core/layout/dialogo_de_formulario.dart';
import '../../../core/layout/margens_do_canvas.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../domain/models/operations.dart';
import '../../finance/presentation/finance_pages.dart';

/// **A minha semana** — o que precisa de mim, e o botão que o resolve.
///
/// **Porque existe.** A app dizia ao gestor onde as coisas estavam (o
/// calendário mostra as reservas, o painel mostra os números) e nunca lhe dizia
/// o que fazer. A decisão do que vem a seguir ficava toda de cabeça, e é de
/// cabeça que as coisas se perdem: o orçamento que ninguém enviou, a máquina
/// que devia ter voltado ontem, os 400 € que nunca foram cobrados.
///
/// **O que este ecrã promete**, e que o resto da app não pode prometer: cada
/// linha tem **um** botão. Não um menu, não três hipóteses — o próximo passo,
/// com um verbo. Quem escolhe é o [proximoPassoDe]; aqui só se desenha.
///
/// Ordenado por urgência e não por data, de propósito: uma entrega atrasada de
/// ontem tem de estar acima de um pedido para daqui a três semanas, mesmo que a
/// agenda diga o contrário.
class MinhaSemanaPage extends ConsumerWidget {
  const MinhaSemanaPage({super.key, this.agora});

  /// A data de referência. Injectável para os testes poderem fixar o dia sem
  /// dependerem do relógio da máquina que os corre.
  final DateTime? agora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(operationsProvider);
    final hoje = agora ?? DateTime.now();
    final trabalhos = aMinhaSemana(state, hoje);
    final atrasados = trabalhos
        .where((item) => item.passo.urgencia == Urgencia.atrasado)
        .length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          MargensDoCanvas.lateral,
          MargensDoCanvas.vertical,
          MargensDoCanvas.lateral,
          MargensDoCanvas.vertical,
        ),
        child: trabalhos.isEmpty
            ? const _NadaPorFazer()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Resumo(total: trabalhos.length, atrasados: atrasados),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: trabalhos.length,
                      itemBuilder: (context, i) =>
                          _CartaoDoTrabalho(item: trabalhos[i], hoje: hoje),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// A linha de cima: quantos há e quantos estão atrasados.
///
/// O número de atrasados só aparece quando existe. Um "0 atrasados" permanente
/// ensina o olho a ignorar aquele sítio do ecrã, e no dia em que lá estiver um
/// 3 já ninguém o lê.
class _Resumo extends StatelessWidget {
  const _Resumo({required this.total, required this.atrasados});
  final int total, atrasados;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          total == 1 ? '1 por fazer' : '$total por fazer',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        if (atrasados > 0) ...[
          const Text('  ·  '),
          Text(
            atrasados == 1 ? '1 atrasado' : '$atrasados atrasados',
            style: TextStyle(fontWeight: FontWeight.w800, color: cores.error),
          ),
        ],
      ],
    );
  }
}

class _NadaPorFazer extends StatelessWidget {
  const _NadaPorFazer();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 44,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        const Text(
          'Nada por fazer.',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 6),
        const Text(
          'Sem pedidos por orçamentar, entregas por fazer nem dinheiro por '
          'receber.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

String _urgenciaLabel(Urgencia urgencia) => switch (urgencia) {
  Urgencia.atrasado => 'Atrasado',
  Urgencia.hoje => 'Hoje',
  Urgencia.aCaminho => 'Esta semana',
};

Color _urgenciaCor(BuildContext context, Urgencia urgencia) {
  final cores = Theme.of(context).colorScheme;
  return switch (urgencia) {
    Urgencia.atrasado => cores.error,
    Urgencia.hoje => cores.primary,
    Urgencia.aCaminho => cores.outline,
  };
}

class _CartaoDoTrabalho extends ConsumerWidget {
  const _CartaoDoTrabalho({required this.item, required this.hoje});
  final TrabalhoComPasso item;
  final DateTime hoje;

  String _maquinas(OperationsState state) {
    final nomes = item.trabalho.machineIds
        .map(
          (id) => state.machines
              .where((maquina) => maquina.id == id)
              .map((maquina) => maquina.reference)
              .firstOrNull,
        )
        .whereType<String>()
        .toList();
    return nomes.join(', ');
  }

  String _cliente(OperationsState state) {
    if (item.trabalho.customerNameSnapshot.isNotEmpty) {
      return item.trabalho.customerNameSnapshot;
    }
    return state.customers
            .where((cliente) => cliente.id == item.trabalho.customerId)
            .map((cliente) => cliente.name)
            .firstOrNull ??
        'Cliente';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(operationsProvider);
    final passo = item.passo;
    final maquinas = _maquinas(state);
    return Card(
      // Mesma margem dos cartões de cliente e de máquina: 3 dp, para caber
      // mais linhas num telemóvel deitado.
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        title: Row(
          children: [
            Flexible(
              child: Text(
                _cliente(state),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _urgenciaLabel(passo.urgencia),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _urgenciaCor(context, passo.urgencia),
              ),
            ),
          ],
        ),
        subtitle: Text(
          maquinas.isEmpty ? passo.porque : '$maquinas · ${passo.porque}',
        ),
        trailing: FilledButton(
          onPressed: () => _executar(context, ref, state),
          child: Text(passo.verbo),
        ),
      ),
    );
  }

  void _executar(BuildContext context, WidgetRef ref, OperationsState state) {
    switch (item.passo.accao) {
      case AccaoDoPasso.avancarEstado:
        // O conflito é devolvido, não lançado: avançar para "confirmada" ou
        // "entregue" volta a verificar a ocupação da máquina, e é aqui que
        // isso pode falhar.
        final conflito = ref
            .read(operationsProvider.notifier)
            .updateBookingStatus(item.trabalho.id, item.passo.estadoSeguinte!);
        if (conflito != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${conflito.machine.name} já está ocupada nestas datas.',
              ),
            ),
          );
        }
      case AccaoDoPasso.declararValor:
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _DialogoDeValor(trabalho: item.trabalho),
        );
      case AccaoDoPasso.registarRecebimento:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RegisterReceiptPage(
              clienteInicial: item.trabalho.customerId,
              trabalhoInicial: item.trabalho.id,
              valorInicialCents: item.passo.valorEmFaltaCents,
            ),
          ),
        );
    }
  }
}

/// Quanto valeu o trabalho, perguntado no momento em que ele fecha.
///
/// Um campo só. É a pergunta mais rentável da app inteira — sem ela o trabalho
/// não conta para a receita nem para a margem — e por isso não pode custar mais
/// do que um número e um toque.
class _DialogoDeValor extends ConsumerStatefulWidget {
  const _DialogoDeValor({required this.trabalho});
  final Booking trabalho;

  @override
  ConsumerState<_DialogoDeValor> createState() => _DialogoDeValorState();
}

class _DialogoDeValorState extends ConsumerState<_DialogoDeValor> {
  final valor = TextEditingController();
  String? erro;

  @override
  void dispose() {
    valor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DialogoDeFormulario(
    titulo: 'Quanto valeu este trabalho?',
    aviso: erro,
    corpo: TextField(
      controller: valor,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Valor (€)',
        helperText: 'O que foi facturado ao cliente, com IVA incluído.',
      ),
    ),
    aoGuardar: () {
      final cents = centsDeTexto(valor.text);
      if (cents == null || cents <= 0) {
        setState(
          () => erro = valor.text.trim().isEmpty
              ? 'Indica um valor superior a zero.'
              : 'Não consigo ler "${valor.text.trim()}" — escreve, por '
                    'exemplo, 1.500,00.',
        );
        return;
      }
      ref
          .read(operationsProvider.notifier)
          .definirValorPrevisto(widget.trabalho.id, cents);
      Navigator.pop(context);
    },
  );
}
