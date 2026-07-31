import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/guidance/guidance_engine.dart';
import '../../../../domain/models/finance.dart';
import '../../../../core/navigation/app_destination.dart';
import '../../../../core/navigation/navigation_controller.dart';
import '../../../../core/operations/kpis.dart';
import '../../../../core/operations/operations_controller.dart';
import '../widgets/celula_semaforo.dart';
import '../widgets/slide_header.dart';

/// Slide 1 · Primeiro impulso (síntese multi-alavanca).
///
/// Pergunta: **estou vivo hoje?** Uma leitura em 5 segundos com 4 células que
/// respondem em cor à urgência de acção.
///
/// **O dinheiro é do mês, não do dia** (Decisão 6 do guião). Quem aluga
/// máquinas não recebe todos os dias: "0 €" às dez da manhã seria um alarme
/// falso todas as manhãs. O dia aparece na sub-linha, como contexto — e a
/// célula abre as Finanças, que é onde as entradas se vão registando à medida
/// que acontecem.
class SinteseSlide extends ConsumerWidget {
  const SinteseSlide({super.key, this.agora});

  /// Injectável para os testes não dependerem do dia em que correm.
  final DateTime? agora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(operationsProvider);
    final now = agora ?? DateTime.now();
    final mes = tesourariaDoMes(estado, now);
    final recomendacao = recomendacaoDaSemana(estado, now);
    final recebidoHoje = receiptTotal(estado.receipts, _dia(now), _dia(now));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SlideHeader(
          icone: Icons.flash_on_outlined,
          nome: 'Primeiro impulso',
          pergunta: 'Estou vivo hoje? Uma leitura em 5 segundos.',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: [
              _AbrirDestino(
                destino: AppDestination.finances,
                child: _entradas(mes, recebidoHoje),
              ),
              _utilizacao(estado),
              _encontroDeContas(mes),
              _recomendacao(recomendacao),
            ],
          ),
        ),
      ],
    );
  }

  /// Dinheiro que entrou **no mês**, com o dia na sub-linha.
  Widget _entradas(TesourariaMes mes, int recebidoHoje) {
    if (mes.recebidoCents == 0 && mes.recebidoMesAnteriorCents == 0) {
      return const CelulaSemaforo(
        nivel: NivelSemaforo.laranja,
        rotulo: 'Dinheiros que entraram',
        texto: 'Por apurar',
        subtexto: 'Regista o primeiro recebimento para começar a medir',
      );
    }
    final variacao = mes.variacaoVsMesAnterior;
    final tendencia = variacao == null
        ? 'Sem mês anterior para comparar'
        : '${variacao >= 0 ? '▲' : '▼'} ${variacao.abs().round()}% vs mês passado';
    return CelulaSemaforo(
      nivel: variacao != null && variacao < 0
          ? NivelSemaforo.laranja
          : NivelSemaforo.verde,
      rotulo: 'Dinheiros que entraram',
      valor: _euros(mes.recebidoCents),
      unidade: '€ este mês',
      subtexto: recebidoHoje > 0
          ? 'Hoje: ${_euros(recebidoHoje)} € · $tendencia'
          : tendencia,
      valorEmDestaque: true,
    );
  }

  /// Ocupação e retorno das máquinas.
  ///
  /// Fica em "Por apurar" enquanto as máquinas não tiverem preço/dia e valor de
  /// compra: sem eles dá para contar dias alugados, mas não para dizer se isso
  /// é bom ou mau — e um número de ocupação sem retorno ao lado é o tipo de
  /// meia-verdade que leva a decisões erradas.
  Widget _utilizacao(OperationsState estado) {
    final comPreco = estado.machines
        .where((m) => !m.archived && m.dailyRateCents != null)
        .length;
    final total = estado.machines.where((m) => !m.archived).length;
    return CelulaSemaforo(
      nivel: NivelSemaforo.laranja,
      rotulo: 'Utilização vs Rentabilidade',
      texto: 'Por apurar',
      subtexto: total == 0
          ? 'Ainda não há máquinas identificadas'
          : comPreco == 0
          ? 'Falta o preço por dia das $total máquinas'
          : 'Falta o preço de ${total - comPreco} de $total máquinas',
    );
  }

  Widget _encontroDeContas(TesourariaMes mes) {
    if (mes.semMovimentos) {
      return const CelulaSemaforo(
        nivel: NivelSemaforo.laranja,
        rotulo: 'Encontro de contas',
        texto: 'Por apurar',
        subtexto: 'Sem entradas nem saídas registadas este mês',
      );
    }
    final saldo = mes.recebidoCents - mes.pagoCents;
    return CelulaSemaforo(
      nivel: saldo >= 0 ? NivelSemaforo.verde : NivelSemaforo.vermelho,
      rotulo: 'Encontro de contas',
      valor: '${saldo >= 0 ? '+ ' : '− '}${_euros(saldo.abs())}',
      unidade: '€ saldo',
      subtexto:
          'Entradas ${_euros(mes.recebidoCents)} · '
          'Saídas ${_euros(mes.pagoCents)}',
      valorEmDestaque: true,
    );
  }

  Widget _recomendacao(Recommendation? recomendacao) {
    if (recomendacao == null) {
      return const CelulaSemaforo(
        nivel: NivelSemaforo.verde,
        rotulo: 'Recomendação do dia',
        texto: 'Nada a assinalar',
        subtexto: 'Sem sinais que peçam acção hoje',
      );
    }
    return CelulaSemaforo(
      nivel: switch (recomendacao.gravidade) {
        GravidadeRecomendacao.oportunidade => NivelSemaforo.verde,
        GravidadeRecomendacao.atencao => NivelSemaforo.laranja,
        GravidadeRecomendacao.urgente => NivelSemaforo.vermelho,
      },
      rotulo: 'Recomendação do dia',
      texto: recomendacao.title,
      subtexto: recomendacao.action,
    );
  }
}

DateTime _dia(DateTime data) => DateTime(data.year, data.month, data.day);

/// Sem casas decimais: o painel é para ler em cinco segundos, e os cêntimos
/// roubam espaço ao que interessa.
String _euros(int cents) => (cents / 100).round().toString();

/// Torna uma célula tocável e leva ao destino operacional correspondente.
///
/// É o padrão editorial da Decisão 7 — cada leitura tem de ter caminho para o
/// sítio onde se age sobre ela. Aqui serve também de resposta ao "campo onde se
/// vão dando as entradas": o valor é do mês, e o toque leva a onde se registam.
class _AbrirDestino extends ConsumerWidget {
  const _AbrirDestino({required this.destino, required this.child});
  final AppDestination destino;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => ref.read(navigationProvider.notifier).goTo(destino),
      child: child,
    ),
  );
}
