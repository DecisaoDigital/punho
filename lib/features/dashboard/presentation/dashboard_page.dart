import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/margens_do_canvas.dart';
import '../../../core/operations/operations_controller.dart';
import 'slides/operacional_slide.dart';
import 'slides/procura_slide.dart';
import 'slides/sintese_slide.dart';
import 'widgets/dots_indicator.dart';

/// Painel de gestão: 3 primeiros slides do brainstorm 9-screens.
///
/// - Slide 1 · **Primeiro impulso** (síntese) — estou vivo hoje?
/// - Slide 2 · **Operacional** — o que faço agora?
/// - Slide 3 · **Procura e vendas** (alavanca) — que alavanca puxo?
///
/// Os restantes 6 (Tesouraria, Margem, Frota, Equipa, Objectivos,
/// Previsibilidade Simulada) entram depois de a UX e integração de dados
/// destes 3 estarem estáveis.
///
/// `PageView` e não carrossel próprio: dá o swipe do tablet de graça, mantém só
/// os slides vizinhos montados e a animação é a do sistema. Um carrossel
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

  static const _nomes = ['Primeiro impulso', 'Operacional', 'Procura e vendas'];

  @override
  void dispose() {
    _controller.dispose();
    _foco.dispose();
    super.dispose();
  }

  void _irPara(int indice) {
    if (indice < 0 || indice >= _nomes.length) return;
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
    // Painel refactorado para a arquitectura de 9 slides do brainstorm
    // (BRAINSTORM_DASHBOARD_9_SCREENS). Nesta fase só os 3 primeiros estão
    // visiveis (Sintese · Operacional · Procura), com dados placeholder para
    // validar a UX. Integração real de dados vem na v0.0.16; alavancas
    // restantes (Tesouraria, Margem, Frota, Equipa, Objectivos, Previsibilidade)
    // entram depois de a UX estabilizar.
    final slides = const [SinteseSlide(), OperacionalSlide(), ProcuraSlide()];

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
            // Os filhos ocupam a largura toda, e não a sua largura mínima.
            //
            // Por omissão o `Column` centra: a saudação ficou a 252,6 dp da
            // margem enquanto os pontinhos por baixo estavam a 15. Não se notou
            // enquanto ela viveu numa `Row` com o botão de editar — era o
            // `Expanded` desse botão que a encostava à esquerda, e saiu com ele.
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              Expanded(
                child: Row(
                  children: [
                    _SetaLateral(
                      icone: Icons.chevron_left,
                      tooltip: 'Slide anterior',
                      onPressed: _slide == 0 ? null : () => _irPara(_slide - 1),
                    ),
                    Expanded(
                      child: PageView(
                        controller: _controller,
                        onPageChanged: (i) => setState(() => _slide = i),
                        children: [
                          for (final slide in slides)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: slide,
                            ),
                        ],
                      ),
                    ),
                    _SetaLateral(
                      icone: Icons.chevron_right,
                      tooltip: 'Slide seguinte',
                      onPressed: _slide == _nomes.length - 1
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
                  nomes: _nomes,
                  activo: _slide,
                  onEscolher: _irPara,
                ),
              ),
            ],
          ),
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
