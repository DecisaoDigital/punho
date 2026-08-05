import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/margens_do_canvas.dart';
import '../../dashboard/presentation/widgets/grelha_de_kpis.dart';
import 'cartao_caixa.dart';

/// **KPIs (todos)** — a lista completa dos indicadores, fora do carrossel.
///
/// O Painel mostra doze KPIs em três slides de quatro, escolhidos para uma
/// leitura de cinco segundos. É uma virtude e é um tecto: um indicador que não
/// caiba nos doze lugares não existe em lado nenhum da app, e a auditoria
/// (`docs/AUDITORIA_KPIS_EMPRESA.md`) identifica quinze que valem a pena — oito
/// deles hoje sem cobertura nenhuma.
///
/// Esta página é onde eles cabem. Um por linha, com espaço para dizer de onde
/// vem o número e — quando não dá para o apurar — que dado falta declarar. Isso
/// não cabe numa célula de painel e é metade do valor: um KPI que não se explica
/// não ensina nada a quem o lê.
///
/// **Nenhum indicador de exemplo.** Os KPIs entram um a um, cada um ligado à
/// sua fonte. O primeiro é a **Caixa**: o que entrou menos o que saiu, do dia 1
/// até hoje, com o acumulado de trás à parte para não condicionar a leitura.
class KpisPage extends ConsumerWidget {
  const KpisPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Os KPIs entram aqui, um por linha, à medida que forem ligados à fonte.
    const cartoes = <Widget>[CartaoCaixa()];

    return SafeArea(
      top: false,
      child: Padding(
        // Começa por texto — o título — logo leva a margem vertical inteira,
        // como o Painel e as Tarefas.
        padding: const EdgeInsets.fromLTRB(
          MargensDoCanvas.lateral,
          MargensDoCanvas.vertical,
          MargensDoCanvas.lateral,
          MargensDoCanvas.vertical,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'KPIs (todos)',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              'Todos os indicadores num sítio só, com a fonte de cada um à '
              'vista. O Painel mostra os doze que cabem em cinco segundos.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Expanded(
              // «tem de ter o mesmo formato e tamanho dos KPIs no dashboard»
              // — Cesar, 5/8/2026. É a grelha do painel, a mesma classe: as
              // células medem-se pela mesma regra, e não por um número copiado
              // para aqui que depois divergia.
              child: GrelhaDeKpis(celulas: cartoes),
            ),
          ],
        ),
      ),
    );
  }
}
