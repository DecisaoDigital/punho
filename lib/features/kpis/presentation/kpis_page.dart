import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/margens_do_canvas.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../core/operations/painel_controller.dart';
import '../../dashboard/presentation/kpi_catalogo.dart';
import '../../dashboard/presentation/pagina_do_painel.dart';
import '../../dashboard/presentation/widgets/kpi_grid_2x2.dart';
import '../domain/sugestao_do_painel.dart';

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

    // **Uma lista só: o que pode subir ao painel, mais o que já lá está.**
    //
    // A bancada teve três grupos — «Prontos», «A chegar» e «Por definir» — e o
    // César mandou-os embora a 10 de Agosto de 2026. Faziam sentido enquanto
    // metade do catálogo estava por verificar; com 23 dos 25 assinados, o que
    // sobrava em baixo era uma lista comprida de coisas que não se podem fazer,
    // à frente das que se podem.
    //
    // O que **não** se pode perder com eles: um KPI que subiu ao painel e
    // depois perdeu a fonte — as «Entregas hoje» num dia sem entregas — tem de
    // continuar à vista para poder sair. Sem isto ficava lá preso a dizer
    // «aguarda» até o dado voltar, que foi um defeito já pago uma vez. Por isso
    // a lista é «prontos ∪ o que está no painel», e não só os prontos.
    final mostraveis = [
      for (final k in catalogoKpis)
        if (k.estado(estado, now) == EstadoVerdade.pronto ||
            arranjo.contem(k.id))
          k,
    ];
    // A ordem do gestor manda; o que ele nunca arrastou vem a seguir, na ordem
    // do catálogo.
    final porId = {for (final k in mostraveis) k.id: k};
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
                // Uma linha só, e leva o que o cabeçalho do grupo levava: quantos
                // há, quantos estão no painel e como se ordenam. O cabeçalho
                // era mais 30 dp para dizer o mesmo.
                //
                // Com a lista vazia diz outra coisa: sem os grupos «A chegar» e
                // «Por definir», uma empresa acabada de abrir ficava com o ecrã
                // em branco e sem saber porquê. Um ecrã vazio tem de dizer que
                // está vazio e o que o enche.
                Text(
                  arrumados.isEmpty
                      ? 'Ainda não há KPIs a dizer verdade. Preenche a ficha da '
                            'empresa e regista o trabalho — eles aparecem aqui '
                            'à medida que a informação entra.'
                      : 'A app cresce contigo: ${arrumados.length} KPIs a dizer '
                            'verdade. '
                            '${noPainel == 0 ? 'Marca os que queres no painel — está vazio.' : '$noPainel no painel · arrasta pela pega para ordenar.'}',
                  style: tt.bodySmall,
                ),
                if (sugestaoDoPainel(estado, arranjo, now) case final s?)
                  _Sugestao(sugestao: s),
                const SizedBox(height: 10),
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
            sliver: SliverToBoxAdapter(
              child: _OsQueFaltam(
                emFalta: [
                  for (final k in catalogoKpis)
                    if (!arrumados.contains(k)) k,
                ],
                estado: estado,
                now: now,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// **A app diz quem devia subir; quem sobe é ele.**
///
/// Uma linha, com o motivo e um botão. É o que restou da «promoção automática»
/// do plano de KPIs — a parte automática não se fez de propósito, e está
/// explicada em `features/kpis/domain/sugestao_do_painel.dart`.
///
/// **Sem botão de dispensar, e é uma escolha.** Um «agora não» que voltasse a
/// aparecer na visita seguinte era uma promessa a fingir; guardá-lo a sério
/// obrigava a gravar dispensas no repositório e a decidir quando é que uma
/// dispensa caduca — trabalho a mais para calar uma linha que se cala sozinha.
/// A sugestão desaparece quando ele a aceita, quando tira o pai do painel, ou
/// quando o número deixa de estar mau. É este ecrã que existe para montar o
/// painel: aqui, a proposta está em casa.
class _Sugestao extends ConsumerWidget {
  const _Sugestao({required this.sugestao});

  final SugestaoDoPainel sugestao;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final cores = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          // A seta de descer um degrau: é literalmente o que a cadeia faz, e
          // uma lâmpada de «dica» prometia um conselho em vez de uma conta.
          Icon(Icons.subdirectory_arrow_right, size: 18, color: cores.primary),
          const SizedBox(width: 6),
          Expanded(child: Text(sugestao.motivo, style: tt.bodySmall)),
          const SizedBox(width: 8),
          TextButton(
            // Sobe **ao lado do pai**, e não para o fim da fila: a explicação
            // longe do número que explica obriga a mudar de página do painel
            // para os ver aos dois.
            onPressed: () => ref
                .read(painelProvider.notifier)
                .porNoPainelJuntoDe(sugestao.kpi.id, depoisDe: sugestao.pai.id),
            child: const Text('Pôr no painel'),
          ),
        ],
      ),
    );
  }
}

/// **O rasto dos que não estão à vista.**
///
/// A bancada mostra só o que diz verdade, e isso é a regra certa — mas deixava
/// o catálogo sem explicação: o César, a 10 de Agosto de 2026, com nove
/// cartões no ecrã de vinte e cinco que existem, perguntou «só me aparecem 9
/// KPIs na bancada, não deveriam ser 15?».
///
/// Não são quinze, e a resposta não é um número: é **o que falta a cada um**.
/// Os grupos «A chegar» e «Por definir» diziam-no e foram embora por ocuparem
/// meio ecrã com coisas que não se podem fazer. Isto é uma linha, fechada, e
/// quem lhe toca é porque quer a lista.
class _OsQueFaltam extends StatefulWidget {
  const _OsQueFaltam({
    required this.emFalta,
    required this.estado,
    required this.now,
  });

  final List<KpiDefinicao> emFalta;
  final OperationsState estado;
  final DateTime now;

  @override
  State<_OsQueFaltam> createState() => _OsQueFaltamState();
}

class _OsQueFaltamState extends State<_OsQueFaltam> {
  var aberto = false;

  @override
  Widget build(BuildContext context) {
    if (widget.emFalta.isEmpty) return const SizedBox(height: 8);
    final tt = Theme.of(context).textTheme;
    final cor = Theme.of(context).colorScheme.outline;
    final quantos = widget.emFalta.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        InkWell(
          onTap: () => setState(() => aberto = !aberto),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  aberto ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: cor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    quantos == 1
                        ? 'Falta 1 KPI — toca para ver o que o acende'
                        : 'Faltam $quantos KPIs — toca para ver o que os acende',
                    style: tt.bodySmall?.copyWith(color: cor),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (aberto)
          for (final kpi in widget.emFalta)
            Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kpi.titulo,
                    style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    // Um KPI com a fonte cheia mas a conta por assinar não
                    // espera por dados nenhuns — espera por nós, e dizer-lhe
                    // "preenche isto" seria mandar o gestor fazer trabalho que
                    // não muda nada.
                    kpi.estado(widget.estado, widget.now) ==
                            EstadoVerdade.porVerificar
                        ? 'Conta por verificar do nosso lado'
                        : kpi.desbloqueio,
                    style: tt.bodySmall?.copyWith(color: cor),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// O ar entre o topo do canvas e a primeira linha desta página.
///
/// Menos do que `MargensDoCanvas.vertical` de propósito, e com medida: no Redmi
/// deitado o canvas tem ~368 dp de altura e três cartões deitados ocupam 268.
/// O que resta para o cabeçalho é meia centena de dp — e o que este ecrã existe
/// para fazer é mostrar KPIs, não apresentar-se.
const _arPorCimaDaLista = 8.0;

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
            //
            // Um toque simples é outra coisa e não colide com nada: abre a
            // cadeia deste KPI, quando ele tem alguma coisa por baixo. Numa
            // folha não abre — não há degrau para descer, e um toque que não
            // faz nada ensina a não tocar.
            Expanded(
              child: AbrirDestinoDoKpi(
                destino: null,
                cadeia: filhosDe(kpi.id).isEmpty ? null : kpi.id,
                agora: now,
                child: kpi.celula(estado, now).deitada(),
              ),
            ),
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
