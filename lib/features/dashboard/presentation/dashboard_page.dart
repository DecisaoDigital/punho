import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/operations/operations_controller.dart';
import '../../company/presentation/company_settings_page.dart';
import 'slides/custos_slide.dart';
import 'slides/dinheiro_slide.dart';
import 'slides/pipeline_slide.dart';
import 'slides/rentabilidade_slide.dart';
import 'slides/semana_slide.dart';
import 'widgets/dots_indicator.dart';

/// Painel de gestão: cinco slides, cada um com quatro KPIs que respondem a uma
/// pergunta.
///
/// O painel anterior punha 17 métricas num `Wrap`, todas do mesmo tamanho e sem
/// ordem — o gestor tinha de escolher onde olhar e a app não ajudava. Aqui cada
/// slide tem uma pergunta no cabeçalho e os quatro números que a respondem.
/// A lista completa continua a existir em `TodasMetricasPage`.
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

  static const _nomes = [
    'Dinheiro',
    'Pipeline',
    'Máquinas',
    'Custos',
    'Semana',
  ];

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
    final slides = [
      // A recomendação do dia manda para os custos ou para o pipeline: é o
      // painel que sabe navegar entre slides, não o slide.
      DinheiroSlide(agora: agora, aoIrParaSlide: _irPara),
      PipelineSlide(agora: agora),
      RentabilidadeSlide(agora: agora),
      CustosSlide(agora: agora),
      SemanaSlide(agora: agora),
    ];

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
          padding: cabecalhoCompacto
              ? const EdgeInsets.fromLTRB(12, 6, 12, 6)
              : const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              _Saudacao(
                state: state,
                agora: agora,
                compacto: cabecalhoCompacto,
              ),
              SizedBox(height: cabecalhoCompacto ? 4 : 10),
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
                              padding: const EdgeInsets.symmetric(horizontal: 4),
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
              DotsIndicator(
                nomes: _nomes,
                activo: _slide,
                onEscolher: _irPara,
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

  String get _data => '${_diasDaSemana[agora.weekday - 1]}, ${agora.day} '
      '${_meses[agora.month - 1]} ${agora.year}';

  String get _dataCurta =>
      '${_diasDaSemana[agora.weekday - 1].substring(0, 3)}., ${agora.day} '
      '${_meses[agora.month - 1].substring(0, 3).toLowerCase()}. ${agora.year}';

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(_data, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
      IconButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CompanySettingsPage()),
        ),
        icon: const Icon(Icons.edit_note),
        tooltip: 'Editar dados da empresa',
      ),
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
