import 'package:flutter/material.dart';

import '../widgets/celula_semaforo.dart';
import '../widgets/slide_header.dart';

/// Slide 2 · Operacional (pulso do dia/semana).
///
/// Pergunta: **o que faço agora?** Reservas, entregas, devoluções, cobranças.
///
/// Estado actual: **layout com dados placeholder** — integração real vem em
/// v0.0.16. Os alertas operacionais (a linha de rodapé) são a síntese dos 4
/// cartões.
class OperacionalSlide extends StatelessWidget {
  const OperacionalSlide({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SlideHeader(
        icone: Icons.pending_actions_outlined,
        nome: 'O pulso do dia',
        pergunta: 'O que faço agora? Reservas, entregas, devoluções, cobranças.',
      ),
      const SizedBox(height: 12),
      Expanded(
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: const [
            CelulaSemaforo(
              nivel: NivelSemaforo.verde,
              rotulo: 'Reservas activas',
              valor: '14',
              unidade: 'em curso',
              subtexto: '4 novas hoje · 2 a terminar',
            ),
            CelulaSemaforo(
              nivel: NivelSemaforo.laranja,
              rotulo: 'Entregas & levantamentos hoje',
              valor: '6',
              unidade: 'por fechar',
              subtexto: '2 já foram · 4 na janela 14h-19h',
            ),
            CelulaSemaforo(
              nivel: NivelSemaforo.vermelho,
              rotulo: 'Devoluções hoje / 48h',
              valor: '3',
              unidade: 'hoje · 5 em 48h',
              subtexto: '1 já em atraso — Sr. Costa',
            ),
            CelulaSemaforo(
              nivel: NivelSemaforo.laranja,
              rotulo: 'Cobranças a vencer (7d)',
              valor: '920',
              unidade: '€ · 4 clientes',
              subtexto: '1 vence hoje (340 €) · 3 na semana',
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Alertas operacionais: 1 atraso · 4 entregas por fechar · 1 cobrança vence hoje',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
  );
}
