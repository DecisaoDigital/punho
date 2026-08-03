import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/operations/kpis.dart';
import '../../../../core/operations/operations_controller.dart';
import '../widgets/celula_semaforo.dart';
import '../widgets/grelha_de_kpis.dart';
import '../widgets/slide_header.dart';

/// Slide 2 · Operacional (pulso do dia/semana).
///
/// Pergunta: **o que faço agora?** Reservas, entregas, recolhas, cobranças.
///
/// É o primeiro slide ligado a dados a sério. Os números vêm todos de
/// [pulsoOperacional]; não há aqui constante nenhuma. Quando não há reservas
/// registadas, as células dizem **o que falta fazer** para o número existir, em
/// vez de mostrarem zeros que parecem informação.
class OperacionalSlide extends ConsumerWidget {
  const OperacionalSlide({super.key, this.agora});

  /// Injectável para os testes não dependerem do dia em que correm.
  final DateTime? agora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(operationsProvider);
    final pulso = pulsoOperacional(estado, agora ?? DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SlideHeader(
          icone: Icons.pending_actions_outlined,
          nome: 'O pulso do dia',
          pergunta:
              'O que faço agora? Reservas, entregas, recolhas, cobranças.',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GrelhaDeKpis(
            celulas: [
              _reservas(pulso),
              _entregas(pulso),
              _recolhas(pulso),
              _cobrancas(pulso),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _Rodape(pulso: pulso),
      ],
    );
  }

  /// A célula que se mostra enquanto não há reservas nenhumas.
  ///
  /// O que ocupa o lugar do número é **o que falta fazer**, não o rótulo
  /// "Por apurar" que aqui estava: quatro células a repeti-lo liam-se como app
  /// avariada, e a razão — que já cá estava — ficava na sub-linha apagada, que
  /// é o último sítio para onde se olha. Um "0" continuaria fora de questão:
  /// seria uma informação que não temos.
  CelulaSemaforo _aguarda(String rotulo, String falta, String contexto) =>
      CelulaSemaforo(
        nivel: NivelSemaforo.aguarda,
        rotulo: rotulo,
        texto: falta,
        subtexto: contexto,
      );

  Widget _reservas(PulsoOperacional p) {
    if (p.semDados) {
      return _aguarda(
        'Reservas activas',
        'Marca a primeira reserva',
        'Põe o pulso do dia a bater',
      );
    }
    return CelulaSemaforo(
      nivel: p.reservasActivas == 0
          ? NivelSemaforo.laranja
          : NivelSemaforo.verde,
      rotulo: 'Reservas activas',
      valor: '${p.reservasActivas}',
      unidade: 'em curso',
      subtexto: p.reservasATerminar48h == 0
          ? 'Nenhuma termina nas próximas 48h'
          : '${p.reservasATerminar48h} terminam em 48h',
    );
  }

  Widget _entregas(PulsoOperacional p) {
    if (p.semDados) {
      return _aguarda(
        'Entregas hoje',
        'Nada para entregar',
        'Vem das reservas marcadas',
      );
    }
    return CelulaSemaforo(
      nivel: p.entregasPorFazer > 0
          ? NivelSemaforo.laranja
          : NivelSemaforo.verde,
      rotulo: 'Entregas hoje',
      valor: '${p.entregasHoje}',
      unidade: p.entregasHoje == 1 ? 'entrega' : 'entregas',
      subtexto: p.entregasHoje == 0
          ? 'Nada para entregar hoje'
          : p.entregasPorFazer == 0
          ? 'Todas já saíram'
          : '${p.entregasPorFazer} por fazer',
    );
  }

  Widget _recolhas(PulsoOperacional p) {
    if (p.semDados) {
      return _aguarda(
        'Recolhas a fazer',
        'Nada para recolher',
        'Vem das reservas a terminar',
      );
    }
    final atrasada = p.recolhasEmAtraso > 0;
    final dias = p.diasDaRecolhaMaisAtrasada;
    final antiguidade = dias == null || dias == 0
        ? ''
        : ' — a mais antiga há $dias dia${dias == 1 ? '' : 's'}';
    return CelulaSemaforo(
      nivel: atrasada
          ? NivelSemaforo.vermelho
          : p.recolhasHoje > 0
          ? NivelSemaforo.laranja
          : NivelSemaforo.verde,
      rotulo: 'Recolhas a fazer',
      valor: '${p.recolhasHoje}',
      unidade: 'hoje · ${p.recolhasProximas48h} em 48h',
      subtexto: atrasada
          ? '${p.recolhasEmAtraso} em atraso$antiguidade'
          : 'Nenhuma máquina por recuperar',
    );
  }

  Widget _cobrancas(PulsoOperacional p) {
    if (p.semDados) {
      return _aguarda(
        'Cobranças a vencer',
        'Nada por cobrar',
        'Vem das reservas por liquidar',
      );
    }
    return CelulaSemaforo(
      nivel: p.venceHojeCents > 0
          ? NivelSemaforo.vermelho
          : p.cobrancasAVencerCents > 0
          ? NivelSemaforo.laranja
          : NivelSemaforo.verde,
      rotulo: 'Cobranças a vencer (7d)',
      valor: '${(p.cobrancasAVencerCents / 100).round()}',
      unidade: p.clientesACobrar == 1
          ? '€ · 1 cliente'
          : '€ · ${p.clientesACobrar} clientes',
      subtexto: p.cobrancasAVencerCents == 0
          ? 'Nada por cobrar nos próximos 7 dias'
          : p.venceHojeCents > 0
          ? 'Vence hoje: ${(p.venceHojeCents / 100).round()} €'
          : 'Nada vence hoje',
    );
  }
}

/// A síntese das quatro células. Encolhe a nada quando não há o que dizer — uma
/// faixa permanente a anunciar "0 alertas" é ruído com ar de informação.
class _Rodape extends StatelessWidget {
  const _Rodape({required this.pulso});
  final PulsoOperacional pulso;

  @override
  Widget build(BuildContext context) {
    final alertas = pulso.alertas;
    if (alertas == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Alertas operacionais: $alertas',
        style: Theme.of(context).textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
