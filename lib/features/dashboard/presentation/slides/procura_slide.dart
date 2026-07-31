import 'package:flutter/material.dart';

import '../widgets/celula_semaforo.dart';
import '../widgets/slide_header.dart';

/// Slide 3 · Alavanca — Procura e Vendas.
///
/// Pergunta: **que alavanca puxo?** Aquisição de clientes · pipeline ·
/// conversão · ticket médio.
///
/// **Estrutura editorial fixa** que se vai repetir nos slides 4-7 (as outras
/// alavancas): cabeçalho + 3-4 KPIs + recomendação canónica + CTA para
/// destino operacional.
///
/// Estado actual: **layout com dados placeholder** — integração real em
/// v0.0.16.
class ProcuraSlide extends StatelessWidget {
  const ProcuraSlide({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SlideHeader(
        icone: Icons.trending_up_outlined,
        nome: 'Procura e vendas · Alavanca',
        pergunta: 'Que alavanca puxo? Aquisição · pipeline · conversão · ticket.',
      ),
      const SizedBox(height: 12),
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 4 KPIs em grelha 2x2 do lado esquerdo (60% da largura)
            Expanded(
              flex: 6,
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.4,
                children: const [
                  CelulaSemaforo(
                    nivel: NivelSemaforo.verde,
                    rotulo: 'Clientes novos (30d)',
                    valor: '17',
                    subtexto: '▲ 6 vs 30d anteriores',
                    valorEmDestaque: true,
                  ),
                  CelulaSemaforo(
                    nivel: NivelSemaforo.laranja,
                    rotulo: 'Leads em pipeline',
                    valor: '9',
                    unidade: 'abertos',
                    subtexto: '3 sem contacto há >5 dias',
                  ),
                  CelulaSemaforo(
                    nivel: NivelSemaforo.verde,
                    rotulo: 'Ticket médio',
                    valor: '42',
                    unidade: '€',
                    subtexto: '▲ 4€ vs mês passado',
                    valorEmDestaque: true,
                  ),
                  CelulaSemaforo(
                    nivel: NivelSemaforo.vermelho,
                    rotulo: 'Conversão lead → cliente',
                    valor: '28',
                    unidade: '%',
                    subtexto: '▼ 9pp — abaixo do alvo (40%)',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Recomendação canónica + CTA (40% da largura)
            Expanded(
              flex: 4,
              child: _CardRecomendacao(),
            ),
          ],
        ),
      ),
    ],
  );
}

class _CardRecomendacao extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primaryContainer.withValues(alpha: 0.55),
            cs.primaryContainer.withValues(alpha: 0.20),
          ],
        ),
        border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RECOMENDAÇÃO CANÓNICA',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.5,
              color: cs.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              'Conversão caiu 9pp num mês. Antes de pagar mais publicidade, '
              'chama os 3 leads sem contacto há >5 dias — historicamente 40% '
              'deles fecham depois do 1º follow-up.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              // TODO(v0.0.16): navegar para Leads com filtro pendentes>5d
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Leads: integração vem na próxima versão.'),
                ),
              );
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Abrir Leads (3 pendentes)'),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
