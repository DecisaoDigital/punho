import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/margens_do_canvas.dart';
import '../../../core/navigation/app_destination.dart';
import '../../../core/navigation/navigation_controller.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../core/operations/painel_controller.dart';
import 'kpi_catalogo.dart';
import 'pagina_do_painel.dart';
import 'widgets/dots_indicator.dart';

/// **O painel é o que o gestor lá puser.**
///
/// Durante meses foram três slides escritos à mão — Síntese, Operacional,
/// Procura —, doze células fixas iguais para toda a gente. Serviram para
/// acertar a leitura, e cumpriram; mas uma empresa que ainda não tem leads
/// abria a app e via quatro caixas a dizer "aguarda". A app parecia não saber
/// nada da vida dela, e nesse ponto tinha razão.
///
/// Agora começa **vazio** e enche-se por escolha, na bancada ("KPIs (todos)"):
/// marca-se o que sobe, arrasta-se para dar a ordem, e o painel pagina-os de
/// quatro em quatro. A ordem da lista é a ordem daqui — não há segunda regra
/// escondida.
///
/// `PageView` e não carrossel próprio: dá o swipe do tablet de graça, mantém só
/// as páginas vizinhas montadas e a animação é a do sistema. Um carrossel
/// manual só se justificava para efeitos que aqui não valem nada.
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key, this.agora});

  /// Injectável para os testes e para as capturas de ecrã terem sempre a mesma
  /// data. Em produção é `DateTime.now()`.
  final DateTime? agora;

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  final _controller = PageController();
  final _foco = FocusNode();
  int _slide = 0;

  /// Quantas páginas há neste momento. Muda quando o gestor marca ou desmarca
  /// um KPI, e é por isso que não pode ser constante.
  int _quantasPaginas = 0;

  @override
  void dispose() {
    _controller.dispose();
    _foco.dispose();
    super.dispose();
  }

  void _irPara(int indice) {
    if (indice < 0 || indice >= _quantasPaginas) return;
    _controller.animateToPage(
      indice,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final agora = widget.agora ?? DateTime.now();
    final state = ref.watch(operationsProvider);
    // Em landscape, a largura de um telefone parece a de um desktop. A menor
    // dimensão é que identifica o dispositivo e evita desperdiçar altura no
    // cabeçalho antes dos indicadores importantes.
    final cabecalhoCompacto = MediaQuery.sizeOf(context).shortestSide < 600;
    final paginas = _paginar(kpisEscolhidos(ref.watch(painelProvider)));
    _quantasPaginas = paginas.length;
    // Desmarcar KPIs encurta o painel debaixo dos pés de quem está na última
    // página. Sem isto, `nomes[activo]` ia buscar uma página que já não existe
    // e o ecrã rebentava a seguir a uma marcação — longe da causa.
    if (_slide >= paginas.length) {
      _slide = paginas.isEmpty ? 0 : paginas.length - 1;
      // O `PageView` guarda a página no controlador, não aqui. Corrigir só o
      // `_slide` deixava a barra a dizer "3/3" com o carrossel parado num
      // sítio que já não tem nada — um painel em branco sem erro nenhum.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(_slide);
      });
    }

    // A moldura superior é desenhada pela shell. Não reservar novamente a
    // mesma área aqui: o cabeçalho deve ficar imediatamente abaixo dela.
    return SafeArea(
      top: false,
      child: Focus(
        focusNode: _foco,
        autofocus: true,
        // Setas do teclado para quem está no PC. O swipe do PageView serve o
        // tablet; sem isto o rato tinha de arrastar a página, que num ecrã
        // grande é desconfortável.
        onKeyEvent: (node, evento) {
          if (evento is! KeyDownEvent) return KeyEventResult.ignored;
          if (evento.logicalKey == LogicalKeyboardKey.arrowRight) {
            _irPara(_slide + 1);
            return KeyEventResult.handled;
          }
          if (evento.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _irPara(_slide - 1);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Padding(
          // O painel começa por texto — a saudação —, portanto leva a margem
          // vertical inteira. Os números vivem em [MargensDoCanvas].
          //
          // O topo só decide a distância porque a saudação encosta ao topo da
          // sua linha; enquanto esteve centrada contra o botão de editar, quem
          // mandava era a altura do botão e mexer aqui não fazia nada.
          padding: const EdgeInsets.fromLTRB(
            MargensDoCanvas.lateralNoCarrossel,
            MargensDoCanvas.vertical,
            MargensDoCanvas.lateralNoCarrossel,
            MargensDoCanvas.vertical,
          ),
          child: Column(
            // Sem `stretch`: a saudação fica **centrada**, e é para ficar.
            //
            // Ficou assim por acidente quando o botão de editar saiu do ecrã —
            // era o `Expanded` dele que a encostava à esquerda. Cheguei a
            // "corrigir" para a margem dos 15 dp, mas o Cesar viu o resultado
            // centrado e preferiu-o. Fica por escolha, não por acaso.
            children: [
              // A saudação e os pontinhos lá em baixo não são setas: somam o ar
              // que a margem do painel desconta por causa delas, para ficarem à
              // mesma distância da barra que o texto de qualquer outro menu.
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MargensDoCanvas.arDaSeta,
                ),
                child: _Saudacao(
                  state: state,
                  agora: agora,
                  compacto: cabecalhoCompacto,
                ),
              ),
              SizedBox(height: cabecalhoCompacto ? 2 : 10),
              if (paginas.isEmpty)
                Expanded(child: _PainelVazio(agora: agora))
              else ...[
                Expanded(
                  child: Row(
                    children: [
                      _SetaLateral(
                        icone: Icons.chevron_left,
                        tooltip: 'Ecrã anterior',
                        onPressed: _slide == 0
                            ? null
                            : () => _irPara(_slide - 1),
                      ),
                      Expanded(
                        child: PageView.builder(
                          controller: _controller,
                          onPageChanged: (i) => setState(() => _slide = i),
                          itemCount: paginas.length,
                          itemBuilder: (context, i) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: PaginaDoPainel(
                              ids: [for (final kpi in paginas[i]) kpi.id],
                              agora: widget.agora,
                            ),
                          ),
                        ),
                      ),
                      _SetaLateral(
                        icone: Icons.chevron_right,
                        tooltip: 'Ecrã seguinte',
                        onPressed: _slide == paginas.length - 1
                            ? null
                            : () => _irPara(_slide + 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MargensDoCanvas.arDaSeta,
                  ),
                  child: DotsIndicator(
                    // Cada ecrã chama-se pelo primeiro KPI que lá está. Podia
                    // ser "Painel 1, 2, 3" — mas quem lê a barra quer saber o
                    // que está do outro lado, e um número não diz nada.
                    nomes: [for (final pagina in paginas) pagina.first.titulo],
                    activo: _slide,
                    onEscolher: _irPara,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Quantos KPIs cabem num ecrã. É a grelha 2×2 de sempre: mais do que isto não
/// é uma leitura de cinco segundos, é uma tabela.
const _porEcra = 4;

/// Parte a lista escolhida em ecrãs de [_porEcra], pela ordem que ela traz.
List<List<KpiDefinicao>> _paginar(List<KpiDefinicao> kpis) => [
  for (var i = 0; i < kpis.length; i += _porEcra)
    kpis.sublist(i, (i + _porEcra).clamp(0, kpis.length)),
];

/// O painel de quem ainda não escolheu nada.
///
/// **Não se põem KPIs "para começar".** Uma sugestão automática seria a app a
/// dizer "isto é o que interessa ao teu negócio" sem saber nada dele — e, pior,
/// a encher o ecrã de células a dizer "aguarda", que foi exactamente o defeito
/// que este painel veio resolver. Diz-se o que falta e leva-se lá.
class _PainelVazio extends ConsumerWidget {
  const _PainelVazio({required this.agora});

  final DateTime agora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    // **Uma empresa acabada de nascer não tem nada para escolher.** Sem
    // reservas nem recebimentos, o catálogo inteiro está em "aguarda" e a
    // bancada não mostra uma única caixa. Mandá-lo lá com "escolhe os que
    // queres" era um convite para uma porta fechada — e a primeira coisa que a
    // app lhe dizia era falso.
    final estado = ref.watch(operationsProvider);
    final haProntos = catalogoKpis.any(
      (k) => k.estado(estado, agora) == EstadoVerdade.pronto,
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.space_dashboard_outlined,
              size: 34,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              haProntos
                  ? 'O painel ainda está vazio'
                  : 'Ainda não há KPIs a dizer verdade',
              textAlign: TextAlign.center,
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              haProntos
                  ? 'Escolhe em "KPIs (todos)" os que queres aqui e arrasta-os '
                        'para a ordem que preferires. Ficam quatro por ecrã.'
                  : 'Vão aparecendo à medida que registares o teu trabalho — '
                        'uma reserva, um recebimento, uma despesa. Em "KPIs '
                        '(todos)" vês quais são e o que falta a cada um.',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => ref
                  .read(navigationProvider.notifier)
                  .goTo(AppDestination.kpis),
              icon: const Icon(Icons.insights_outlined, size: 18),
              label: Text(haProntos ? 'Escolher KPIs' : 'Ver o que falta'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cabeçalho fixo: quem é, que dia é, e a entrada para os dados da empresa.
class _Saudacao extends StatelessWidget {
  const _Saudacao({
    required this.state,
    required this.agora,
    required this.compacto,
  });
  final OperationsState state;
  final DateTime agora;
  final bool compacto;

  static const _diasDaSemana = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];
  static const _meses = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  String get _nome => state.ownerName ?? state.companyName;

  String get _data =>
      '${_diasDaSemana[agora.weekday - 1]}, ${agora.day} '
      '${_meses[agora.month - 1]} ${agora.year}';

  String get _dataCurta =>
      '${_diasDaSemana[agora.weekday - 1].substring(0, 3)}., ${agora.day} '
      '${_meses[agora.month - 1].substring(0, 3).toLowerCase()}. ${agora.year}';

  // Sem o ícone de editar que vivia à direita desta linha.
  //
  // Os dados da empresa continuam a três toques de distância — pelo Perfil,
  // pelo menu Empresa e pelas Tarefas que lá levam —, e o painel deixa de ter
  // um alvo de toque de 48 dp a decidir a altura de uma linha de 19.
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (compacto) ...[
        Text(
          '$_nome · $_dataCurta',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ] else ...[
        Text(
          _nome,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(_data, style: Theme.of(context).textTheme.bodySmall),
      ],
    ],
  );
}

class _SetaLateral extends StatelessWidget {
  const _SetaLateral({
    required this.icone,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icone;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: tooltip,
    icon: Icon(icone),
    iconSize: 26,
    visualDensity: VisualDensity.compact,
  );
}
