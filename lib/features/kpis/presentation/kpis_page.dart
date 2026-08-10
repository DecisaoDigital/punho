import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/margens_do_canvas.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../core/operations/painel_controller.dart';
import '../../../domain/models/arranjo_do_painel.dart';
import '../../dashboard/presentation/kpi_catalogo.dart';
import '../../dashboard/presentation/widgets/kpi_grid_2x2.dart';

/// **KPIs (todos)** — a bancada. Todos os indicadores num sítio só, cada um a
/// dizer em que ponto de verdade está, e daqui é que se monta o painel.
///
/// A ideia do César (9 Ago 2026): a app **cresce com o empresário**. À medida
/// que ele preenche informação, vê KPIs *a chegar* — não leva tudo de repente,
/// amadurece a gestão dia a dia. Por isso a lista agrupa-se pelo estado de
/// verdade de cada KPI:
///  - **Prontos** — fonte cheia e conta já verificada por nós: podem subir ao
///    painel a dizer verdade. São os únicos que se marcam.
///  - **A chegar** — já têm dados, falta o nosso crivo à fórmula.
///  - **Por definir** — falta a informação que os acende, e diz-se qual.
///
/// **Só os prontos se marcam**, e é a regra inteira. Deixar promover um que
/// ainda não passou pelo crivo era pôr no painel um número que nós próprios
/// não assinamos — e o painel só vale enquanto se puder acreditar nele sem
/// perguntar nada a ninguém.
///
/// A caixa fica à **esquerda** e a pega à **direita**: são dois gestos
/// diferentes e à mesma distância do polegar não se distinguem. No meio, a
/// célula verdadeira — escolhe-se o KPI a olhar para o que ele vai mostrar, e
/// não para o nome dele numa lista.
class KpisPage extends ConsumerWidget {
  const KpisPage({super.key, this.agora});

  /// Injectável para os testes não dependerem do dia em que correm.
  final DateTime? agora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(operationsProvider);
    final arranjo = ref.watch(painelProvider);
    final now = agora ?? DateTime.now();

    final prontos = <KpiDefinicao>[];
    final aChegar = <KpiDefinicao>[];
    final porDefinir = <KpiDefinicao>[];
    for (final k in catalogoKpis) {
      switch (k.estado(estado, now)) {
        case EstadoVerdade.pronto:
          prontos.add(k);
        case EstadoVerdade.porVerificar:
          aChegar.add(k);
        case EstadoVerdade.porDefinir:
          porDefinir.add(k);
      }
    }
    // A ordem do gestor manda nos prontos; o que ele nunca arrastou vem a
    // seguir, na ordem do catálogo.
    final porId = {for (final k in prontos) k.id: k};
    final arrumados = [
      for (final id in arranjo.arrumar(porId.keys))
        if (porId[id] case final k?) k,
    ];

    final tt = Theme.of(context).textTheme;
    // Conta só os que esta versão conhece: um painel arrumado numa app mais
    // nova dizia aqui "6 no painel" com quatro cartões no ecrã.
    final noPainel = kpisEscolhidos(arranjo).length;

    // **Slivers e não uma `ListView` com a lista arrastável lá dentro.**
    //
    // Assim é que o arrasto rola a página. Uma `ReorderableListView` embrulhada
    // com `shrinkWrap` procura o `Scrollable` mais próximo para rolar sozinha —
    // e esse é ela própria, que com `shrinkWrap` não tem para onde rolar. A
    // página de fora também não rolava, porque o gesto já tinha sido ganho pela
    // pega. No Redmi deitado cabe linha e meia: levar um KPI do fim para o
    // princípio dava oito largadas.
    const margem = EdgeInsets.symmetric(horizontal: MargensDoCanvas.lateral);
    return SafeArea(
      top: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: margem.copyWith(top: _arPorCimaDaLista),
            sliver: SliverList.list(
              children: [
                // **Sem título repetido e com uma linha só de explicação.**
                //
                // O ecrã já se chama «KPIs (todos)» na barra lateral, e a
                // barra está sempre à vista. Repeti-lo aqui custava 24 dp; a
                // explicação em quatro linhas custava outros 48. No Redmi
                // deitado o cabeçalho comia 133 dp dos 368 do canvas — e nem
                // três cartões inteiros cabiam. Agora cabem, que é o que o
                // ecrã existe para fazer.
                Text(
                  'A app cresce contigo: os KPIs vão chegando à medida que '
                  'preencheres a informação. Arrasta pela pega para ordenar.',
                  style: tt.bodySmall,
                ),
                const SizedBox(height: 10),
                if (arrumados.isNotEmpty) ...[
                  _CabecalhoGrupo(
                    titulo: 'Prontos',
                    nota: noPainel == 0
                        ? 'marca os que queres no painel — está vazio'
                        : '$noPainel no painel · arrasta pela pega para ordenar',
                    cor: _corPronto,
                    contagem: arrumados.length,
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          SliverPadding(
            padding: margem,
            sliver: SliverReorderableList(
              itemCount: arrumados.length,
              // A linha levantada vai para o `Overlay`, e lá em cima já não tem
              // o `Material` da página por baixo — a caixa de marcar rebentava
              // a meio do arrasto. A `ReorderableListView` trazia um decorador
              // por omissão que fazia isto; a versão em sliver não traz.
              proxyDecorator: (linha, _, animacao) => AnimatedBuilder(
                animation: animacao,
                builder: (context, filho) => Material(
                  color: Colors.transparent,
                  shadowColor: Theme.of(context).colorScheme.shadow,
                  elevation: Curves.easeInOut.transform(animacao.value) * 6,
                  borderRadius: BorderRadius.circular(12),
                  child: filho,
                ),
                child: linha,
              ),
              // `onReorderItem` e não `onReorder`: este já vem com o índice de
              // destino descontado do buraco que a linha arrastada deixou. Com
              // o antigo, arrastar para baixo parava uma posição antes do sítio
              // onde se largou, e o desconto ficava por conta de quem o usasse.
              onReorderItem: (de, para) {
                final ids = [for (final k in arrumados) k.id];
                ids.insert(para, ids.removeAt(de));
                ref.read(painelProvider.notifier).reordenar(ids);
              },
              itemBuilder: (context, i) => _LinhaDeKpi(
                key: ValueKey(arrumados[i].id),
                kpi: arrumados[i],
                marcado: arranjo.contem(arrumados[i].id),
                indiceParaArrastar: i,
                estado: estado,
                now: now,
              ),
            ),
          ),
          SliverPadding(
            padding: margem.copyWith(bottom: MargensDoCanvas.vertical),
            sliver: SliverList.list(
              children: [
                if (arrumados.isNotEmpty) const SizedBox(height: 10),
                ..._grupo(
                  context,
                  titulo: 'A chegar',
                  nota: 'já têm dados, falta o nosso crivo à fórmula',
                  cor: _corAChegar,
                  kpis: aChegar,
                  arranjo: arranjo,
                  estado: estado,
                  now: now,
                ),
                ..._grupo(
                  context,
                  titulo: 'Por definir',
                  nota: 'falta a informação que os acende',
                  cor: Theme.of(context).colorScheme.outline,
                  kpis: porDefinir,
                  arranjo: arranjo,
                  estado: estado,
                  now: now,
                  mostrarDesbloqueio: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _grupo(
    BuildContext context, {
    required String titulo,
    required String nota,
    required Color cor,
    required List<KpiDefinicao> kpis,
    required ArranjoDoPainel arranjo,
    required OperationsState estado,
    required DateTime now,
    bool mostrarDesbloqueio = false,
  }) {
    if (kpis.isEmpty) return const [];
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return [
      _CabecalhoGrupo(
        titulo: titulo,
        nota: nota,
        cor: cor,
        contagem: kpis.length,
      ),
      const SizedBox(height: 10),
      for (final k in kpis) ...[
        // **Aqui a caixa só aparece a quem já está no painel.** Um KPI que
        // subiu quando tinha dados e os perdeu — as entregas de hoje, num dia
        // sem entregas — cai deste lado da lista, e continua no painel a dizer
        // "aguarda". Sem caixa nenhuma ficava lá preso, sem forma de sair, até
        // o dado voltar. Marcá-lo é que não se pode: promover ao painel é só
        // dos prontos.
        _LinhaDeKpi(
          kpi: k,
          marcado: arranjo.contem(k.id) ? true : null,
          estado: estado,
          now: now,
        ),
        if (mostrarDesbloqueio)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              _larguraDaMarca + 8,
              5,
              _larguraDaPega + 8,
              0,
            ),
            child: Text(
              'Desbloqueia com: ${k.desbloqueio}',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        // Sem `SizedBox` a somar-se: a linha já traz o seu próprio ar por
        // baixo. Somavam-se os dois, e estes grupos ficavam com o dobro do
        // espaçamento dos "Prontos" — a mesma lista com duas medidas.
      ],
      const SizedBox(height: 10),
    ];
  }
}

/// O ar entre o topo do canvas e a primeira linha desta página.
///
/// Menos do que `MargensDoCanvas.vertical` de propósito, e com medida: no Redmi
/// deitado o canvas tem ~368 dp de altura e três cartões deitados ocupam 268.
/// O que resta para o cabeçalho é meia centena de dp — e o que este ecrã existe
/// para fazer é mostrar KPIs, não apresentar-se.
const _arPorCimaDaLista = 8.0;

const _corPronto = Color(0xFF3DC97A);
const _corAChegar = Color(0xFFFFB246);

/// A coluna da caixa de marcar, à esquerda. É o alvo de toque mínimo do
/// Material (48 dp) — abaixo disto falha-se a marcação com o dedo.
const _larguraDaMarca = 48.0;

/// A coluna da pega de arrastar, à direita.
///
/// **48 dp, o alvo mínimo do Material** — os mesmos da caixa de marcar. Esteve
/// em 40, com o argumento de que arrastar se aceita numa faixa mais estreita
/// porque o gesto começa devagar e corrige-se. Não se corrigia: o alvo era o
/// ícone de 24 dp no meio da coluna, e falhá-lo parecia a app a não responder.
///
/// Agora a coluna inteira pega, e é só ela: «só nos 6 pontinhos e pouco mais»,
/// pediu o César a 10 de Agosto de 2026, depois de eu ter posto o cartão todo
/// a arrastar. Os 8 dp que isto custa à célula não se dão por eles; falhar a
/// pega dá-se sempre.
const _larguraDaPega = 48.0;

/// Uma linha da lista: marcar à esquerda, o KPI no meio, a pega de arrastar à
/// direita.
///
/// As duas pontas são opcionais e as colunas ficam à mesma: sem caixa e sem
/// pega, o espaço reserva-se na mesma para as células de todos os grupos
/// alinharem umas por baixo das outras.
class _LinhaDeKpi extends ConsumerWidget {
  const _LinhaDeKpi({
    super.key,
    required this.kpi,
    required this.marcado,
    required this.estado,
    required this.now,
    this.indiceParaArrastar,
  });

  final KpiDefinicao kpi;

  /// `null` quando este KPI não se pode marcar nem desmarcar — não está pronto
  /// e também não está no painel.
  final bool? marcado;

  /// `null` fora da lista que se arrasta.
  final int? indiceParaArrastar;

  final OperationsState estado;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marcado = this.marcado;
    final indice = indiceParaArrastar;
    return Padding(
      padding: const EdgeInsets.only(bottom: AlturaDoKpi.entreDeitados),
      child: SizedBox(
        // O cartão **deitado**: rótulo e número na mesma linha. A altura é
        // medida (`AlturaDoKpi.deitado`), não inventada — e é aqui que a
        // bancada deixou de gastar 150 dp e metade da largura por KPI.
        height: AlturaDoKpi.deitado,
        child: Row(
          children: [
            SizedBox(
              width: _larguraDaMarca,
              child: marcado == null
                  ? null
                  : Checkbox(
                      value: marcado,
                      onChanged: (novo) => ref
                          .read(painelProvider.notifier)
                          .alternar(kpi.id, escolher: novo ?? false),
                      // Lido em voz alta, "caixa de verificação, marcada" não
                      // diz de quê: numa lista de catorze linhas iguais isso
                      // não chega.
                      semanticLabel: '${kpi.titulo} no painel',
                    ),
            ),
            // **O cartão não pega.** Chegou a pegar — meio segundo em cima dele
            // levantava-o — e o César cortou: «não quero o card todo a ficar
            // activo, deve ser só nos 6 pontinhos e pouco mais». O cartão é
            // para se ler; quem manda nele é a pega, aqui à direita.
            Expanded(child: kpi.celula(estado, now).deitada()),
            SizedBox(
              width: _larguraDaPega,
              child: indice == null
                  ? null
                  : ReorderableDragStartListener(
                      index: indice,
                      // **Sem `Tooltip`.** O tooltip abre ao fim de meio
                      // segundo de dedo em cima e leva o gesto com ele: quem
                      // segurava a pega à espera de a poder mexer via aparecer
                      // um balão preto e o cartão não saía do sítio. A dica
                      // não valia o gesto que custava — o que ela dizia passou
                      // para a semântica, onde não disputa nada.
                      child: Semantics(
                        label: 'Arrastar ${kpi.titulo} para ordenar',
                        // Opaco e a ocupar a coluna toda: o alvo era o ícone de
                        // 24 dp no meio de 40, e falhar a pega parecia a app a
                        // não responder.
                        child: Container(
                          color: Colors.transparent,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.drag_indicator,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// O cabeçalho de um grupo do estado de verdade: um ponto da cor do grupo, o
/// nome, a contagem, e uma nota curta a dizer o que o grupo significa.
class _CabecalhoGrupo extends StatelessWidget {
  const _CabecalhoGrupo({
    required this.titulo,
    required this.nota,
    required this.cor,
    required this.contagem,
  });

  final String titulo;
  final String nota;
  final Color cor;
  final int contagem;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          '$titulo · $contagem',
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            nota,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
