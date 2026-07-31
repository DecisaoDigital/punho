import 'package:flutter/material.dart';

import '../widgets/celula_semaforo.dart';
import '../widgets/slide_header.dart';

/// Slide 1 · Primeiro impulso (síntese multi-alavanca).
///
/// Pergunta: **estou vivo hoje?** Uma leitura em 5 segundos com 4 células que
/// respondem em cor (verde/laranja/vermelho) à urgência de acção.
///
/// Estado actual: **layout com dados placeholder** — a integração real com os
/// KPIs vem a seguir (v0.0.16). Este slide fica com números fixos até lá para
/// validarmos a UX antes de gastar tempo com os cálculos.
class SinteseSlide extends StatelessWidget {
  const SinteseSlide({super.key});

  @override
  Widget build(BuildContext context) => Column(
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
          childAspectRatio: 1.6,
          children: const [
            CelulaSemaforo(
              nivel: NivelSemaforo.verde,
              rotulo: 'Dinheiros que entraram',
              valor: '1 240',
              unidade: '€ hoje',
              subtexto: '▲ 18% vs mesmo dia semana passada',
              valorEmDestaque: true,
            ),
            CelulaSemaforo(
              nivel: NivelSemaforo.laranja,
              rotulo: 'Utilização vs Rentabilidade',
              valor: '72',
              unidade: '% util · 4,10€/h',
              subtexto: 'Máq. 3 abaixo do alvo (3,20 €/h)',
            ),
            CelulaSemaforo(
              nivel: NivelSemaforo.verde,
              rotulo: 'Encontro de contas',
              valor: '+ 380',
              unidade: '€ saldo',
              subtexto: 'Entradas 1 240 · Saídas 860',
              valorEmDestaque: true,
            ),
            CelulaSemaforo(
              nivel: NivelSemaforo.vermelho,
              rotulo: 'Recomendação do dia',
              texto: 'Cobrar Silva & Filhos (vence hoje — 340 €)',
              subtexto: 'Urgência: alta · abre em Tesouraria',
            ),
          ],
        ),
      ),
    ],
  );
}
