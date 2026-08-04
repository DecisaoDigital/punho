/// Formulários em ecrã completo, com o teclado a caber.
///
/// Porque existe: em paisagem com o teclado aberto sobram cerca de 200 dp de
/// altura. Um `Dialog` centra-se verticalmente, tem margens fixas e não
/// negoceia com `viewInsets` — o que ficava à vista era o título e o botão
/// *Guardar*, sem um único campo utilizável pelo meio. Em retrato o mesmo
/// defeito aparece mais suave: o campo existe, mas é preciso posicioná-lo com
/// o dedo antes de escrever.
///
/// A app é de gestores e corre deitada. Travar a orientação não é solução —
/// resolve-se dando ao formulário o ecrã inteiro, que é a única superfície que
/// encolhe com o teclado em vez de ser encolhida por ele.
///
/// Substitui `DialogoDeFormulario`, que fica só enquanto houver formulários
/// por migrar.
library;

import 'package:flutter/material.dart';

import 'margens_do_canvas.dart';

/// Abre um formulário em ecrã completo e devolve o que ele devolver.
///
/// `fullscreenDialog: true` não é decoração: muda a animação para vertical e o
/// botão de retorno para um X. Diz ao utilizador que isto é uma tarefa que se
/// fecha, não um sítio para onde se navegou.
Future<T?> abrirFormulario<T>(BuildContext context, WidgetBuilder construtor) =>
    Navigator.of(context).push<T>(
      MaterialPageRoute<T>(builder: construtor, fullscreenDialog: true),
    );

/// Formulário de criação ou edição, em ecrã completo.
///
/// Os [campos] entram por ordem de tabulação. Os que forem [CampoDeTexto]
/// ficam ligados entre si: *Seguinte* no teclado passa ao próximo, e ao ganhar
/// foco cada um sobe até ficar à vista sem ninguém lhe tocar. Os outros
/// widgets — dropdowns, escolhas de data, blocos inteiros — entram na lista
/// tal como estão.
class EcraDeFormulario extends StatefulWidget {
  const EcraDeFormulario({
    super.key,
    required this.titulo,
    required this.campos,
    required this.aoGuardar,
    this.aoCancelar,
    this.guardarAtivo = true,
    this.aviso,
    this.rotuloGuardar = 'Guardar',
  });

  final String titulo;

  /// Ordem da lista = ordem de tabulação = ordem no ecrã.
  final List<Widget> campos;

  final VoidCallback aoGuardar;

  /// Corre quando o utilizador confirma que sai sem gravar. Serve para desfazer
  /// o que o formulário tenha deixado escrito noutro sítio — uma fotografia já
  /// copiada para o disco, por exemplo.
  final VoidCallback? aoCancelar;

  final bool guardarAtivo;

  /// Recusa a mostrar a quem carregou em *Guardar*, logo por cima do rodapé.
  ///
  /// Fica **fora** do scroll de propósito, como ficava no diálogo que isto
  /// substitui. Estas mensagens andavam em `SnackBar`, que num telemóvel
  /// deitado nasce por baixo do teclado: a gravação era recusada e o que se via
  /// era o botão a não fazer nada.
  final String? aviso;

  /// O formulário da máquina usa "Guardar e identificar" quando está a baptizar
  /// uma linha criada pelo total declarado no onboarding.
  final String rotuloGuardar;

  @override
  State<EcraDeFormulario> createState() => _EcraDeFormularioState();
}

class _EcraDeFormularioState extends State<EcraDeFormulario> {
  final _registo = RegistoDeCampos();

  /// Ergue-se enquanto o `aoGuardar` corre, para o `Navigator.pop` de quem
  /// gravou não ir bater no aviso de "tem alterações por guardar" — que é o que
  /// aconteceria, já que gravar deixa sempre alterações por trás.
  bool _aGravar = false;

  @override
  void dispose() {
    _registo.dispose();
    super.dispose();
  }

  void _guardar() {
    // O `setState` tem de chegar à árvore antes do `pop`: o `canPop` que vale é
    // o da última construção, não o do campo neste instante.
    setState(() => _aGravar = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.aoGuardar();
      // Se gravou, já cá não estamos. Se a validação recusou, volta a valer o
      // aviso de saída.
      if (mounted) setState(() => _aGravar = false);
    });
  }

  Future<void> _confirmarSaida() async {
    final sair = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Sair sem guardar?'),
        content: const Text('O que escreveu perde-se.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('Continuar a preencher'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogo, true),
            child: const Text('Sair sem guardar'),
          ),
        ],
      ),
    );
    if (sair == true && mounted) {
      widget.aoCancelar?.call();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final mq = MediaQuery.of(context);
    final insets = mq.viewInsets.bottom;
    // O que sobra de ecrã depois do teclado. Medido no Redmi Note 10 Pro
    // deitado: 393 dp de altura, o teclado leva 200, restam 193 — e a barra de
    // topo mais as margens ainda comem 56 desses. Um campo em tamanho normal
    // ocupa 56 dp; dois já não cabiam.
    final alturaUtil = mq.size.height - insets;
    final apertado = alturaUtil < 420;
    return ValueListenableBuilder<bool>(
      valueListenable: _registo.alterado,
      builder: (context, alterado, filho) => PopScope(
        canPop: _aGravar || !alterado,
        onPopInvokedWithResult: (saiu, _) {
          if (!saiu) _confirmarSaida();
        },
        child: filho!,
      ),
      // Mensageiro próprio, e não o da app.
      //
      // Um `SnackBar` mostra-se em **todos** os `Scaffold` registados no mesmo
      // mensageiro. Enquanto isto foi diálogo não havia `Scaffold` nenhum aqui;
      // agora há, e a mensagem que o ecrã de baixo mandava mostrar ao fechar o
      // formulário aparecia duas vezes — uma em cada — durante a animação de
      // saída. Cada formulário fica com o seu.
      child: ScaffoldMessenger(
        child: Scaffold(
          // O ponto todo: é isto que faz o corpo encolher com o teclado em vez de
          // ficar por baixo dele.
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            // Apertado, a barra encolhe: são 12 dp que passam a ser campo.
            toolbarHeight: apertado ? 44 : null,
            title: Text(widget.titulo),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton(
                  onPressed: widget.guardarAtivo ? _guardar : null,
                  child: Text(widget.rotuloGuardar),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: RegistoDeCamposHerdado(
                    registo: _registo,
                    apertado: apertado,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        MargensDoCanvas.lateral,
                        apertado ? 6 : MargensDoCanvas.vertical,
                        MargensDoCanvas.lateral,
                        // O teclado mais 16: sem esta soma, o último campo fica
                        // colado à aresta de cima do teclado e não se lê o que se
                        // está a escrever.
                        insets + 16,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) =>
                            _corpo(constraints.maxWidth, apertado),
                      ),
                    ),
                  ),
                ),
                if (widget.aviso != null)
                  Container(
                    width: double.infinity,
                    color: tema.colorScheme.errorContainer,
                    padding: const EdgeInsets.symmetric(
                      horizontal: MargensDoCanvas.lateral,
                      vertical: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 18,
                          color: tema.colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.aviso!,
                            style: tema.textTheme.bodySmall?.copyWith(
                              color: tema.colorScheme.onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Uma coluna por cada 250 dp de largura, até três.
  ///
  /// O número sai de uma medição e não de um gosto. No Redmi Note 10 Pro
  /// deitado, com o teclado aberto: ecrã 872,7 × 392,7 dp, teclado 200,4 dp de
  /// altura, sobram 192,4 — e ao corpo do formulário chegam 761,6 dp de
  /// largura, já descontadas as margens e o que o entalhe e a barra de gestos
  /// levam de lado.
  ///
  /// A altura é que escasseia; a largura sobra. Três colunas de 240 dp cabem
  /// nessa largura e põem seis campos à vista de uma vez, onde duas punham
  /// dois. Abaixo de 250 dp por coluna os rótulos longos — "Manutenção
  /// prevista — valor anual (€)" — começam a cortar.
  ///
  /// A divisão é sequencial e não alternada: os primeiros campos na coluna da
  /// esquerda, os últimos na da direita. Alternar punha o campo 2 ao lado do 1
  /// e lia-se a saltar.
  ///
  /// Um [CampoLargo] — ou um [CampoDeTexto] de várias linhas — quebra a divisão
  /// e ocupa a largura toda.
  Widget _corpo(double largura, bool apertado) {
    final colunas = (largura / 250).floor().clamp(1, 3);
    if (colunas == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final campo in widget.campos) _comAr(campo, apertado)],
      );
    }

    final blocos = <Widget>[];
    var estreitos = <Widget>[];

    void despejar() {
      if (estreitos.isEmpty) return;
      // Por linhas e não por colunas cheias: com 8 campos em 3 colunas dá 3+3+2
      // — o que interessa é que a primeira linha esteja cheia, porque é a única
      // que se vê com o teclado aberto.
      final porColuna = (estreitos.length / colunas).ceil();
      // E depois conta-se quantas colunas isso enche mesmo. Quatro campos em
      // três colunas dão duas de dois e uma vazia; a coluna vazia não desaparece
      // sozinha — fica lá a ocupar um terço da largura e a estreitar as outras
      // duas sem nada dentro.
      final usadas = (estreitos.length / porColuna).ceil();
      final fatias = <List<Widget>>[];
      for (var i = 0; i < usadas; i++) {
        final inicio = i * porColuna;
        if (inicio >= estreitos.length) {
          fatias.add(const []);
        } else {
          final fim = (inicio + porColuna).clamp(0, estreitos.length);
          fatias.add(estreitos.sublist(inicio, fim));
        }
      }
      blocos.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < usadas; i++) ...[
              if (i > 0) const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: fatias[i],
                ),
              ),
            ],
          ],
        ),
      );
      estreitos = <Widget>[];
    }

    for (final campo in widget.campos) {
      if (_ocupaTudo(campo)) {
        despejar();
        blocos.add(_comAr(campo, apertado));
      } else {
        estreitos.add(_comAr(campo, apertado));
      }
    }
    despejar();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: blocos,
    );
  }

  static bool _ocupaTudo(Widget campo) =>
      campo is CampoLargo || (campo is CampoDeTexto && campo.linhas > 1);

  static Widget _comAr(Widget campo, bool apertado) => Padding(
    padding: EdgeInsets.only(bottom: apertado ? 6 : 12),
    child: campo,
  );
}

/// Marca um widget para ocupar a largura toda mesmo em duas colunas.
///
/// Serve para o que não é um campo: um bloco de estimativa, uma grelha de
/// fotografias, uma escolha de vínculo. Partidos ao meio ficavam ilegíveis.
class CampoLargo extends StatelessWidget {
  const CampoLargo(this.filho, {super.key});

  final Widget filho;

  @override
  Widget build(BuildContext context) => filho;
}

/// Um campo de texto que se inscreve no formulário à volta.
///
/// Da inscrição vem tudo o que um `TextField` solto não consegue fazer sozinho:
/// saber quem é o campo a seguir para lhe passar o foco, subir até ficar à
/// vista quando o teclado abre por baixo dele, e dizer ao ecrã se há alterações
/// por guardar.
///
/// Fora de um [EcraDeFormulario] funciona na mesma, como um `TextField` normal.
class CampoDeTexto extends StatefulWidget {
  const CampoDeTexto({
    super.key,
    required this.controlador,
    required this.rotulo,
    this.ajuda,
    this.teclado,
    this.capitalizacao = TextCapitalization.none,
    this.linhas = 1,
    this.oculto = false,
    this.autofocus = false,
    this.aoMudar,
    this.aviso,
  });

  final TextEditingController controlador;
  final String rotulo;

  /// A linha por baixo do campo. É onde se diz o que o rótulo não cabe a dizer.
  final String? ajuda;

  final TextInputType? teclado;
  final TextCapitalization capitalizacao;

  /// Acima de 1 o campo ocupa a largura toda e o teclado passa a ter Enter em
  /// vez de *Seguinte* — num campo de notas, mudar de linha é o que se quer.
  final int linhas;

  final bool oculto;
  final bool autofocus;
  final ValueChanged<String>? aoMudar;

  /// Aviso âmbar por baixo do campo: "confere isto", não "isto está mal".
  ///
  /// `errorText` seria mentira num NIF a meio de ser escrito — não há erro, há
  /// um número por acabar. Ao contrário da [ajuda], não desaparece quando o
  /// espaço aperta: quem está a ser avisado precisa de ver o aviso.
  final String? aviso;

  @override
  State<CampoDeTexto> createState() => _CampoDeTextoState();
}

class _CampoDeTextoState extends State<CampoDeTexto> {
  final _no = FocusNode();
  RegistoDeCampos? _registo;
  int _indice = -1;

  @override
  void initState() {
    super.initState();
    _no.addListener(_aoMudarFoco);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registo = RegistoDeCamposHerdado.talvezDe(context);
    if (registo != null && registo != _registo) {
      _registo = registo;
      _indice = registo.inscrever(_no, widget.controlador);
    }
  }

  /// Sobe o campo até ficar à vista quando ganha o foco.
  ///
  /// `alignment: 0.1` põe-no perto do topo da área visível e não colado a ela:
  /// deixa ver o campo anterior, que é o que diz ao utilizador onde está.
  void _aoMudarFoco() {
    if (!_no.hasFocus || !mounted) return;
    // Um frame de espera porque o `viewInsets` do teclado ainda não chegou: sem
    // isto, o cálculo é feito contra o ecrã inteiro e o campo fica por baixo do
    // teclado que estava prestes a abrir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.1,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _registo?.riscar(_indice);
    _no.removeListener(_aoMudarFoco);
    _no.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final multilinha = widget.linhas > 1;
    final apertado = RegistoDeCamposHerdado.apertadoEm(context);
    return ValueListenableBuilder<int>(
      // O último campo mostra ✓ em vez de →. Só se sabe qual é depois de todos
      // se inscreverem, e por isso é que isto é um `ValueListenable` e não um
      // parâmetro.
      valueListenable: _registo?.total ?? ValueNotifier<int>(0),
      builder: (context, total, _) {
        final ultimo = _indice >= 0 && _indice == total - 1;
        return TextField(
          controller: widget.controlador,
          focusNode: _no,
          autofocus: widget.autofocus,
          keyboardType:
              widget.teclado ??
              (multilinha ? TextInputType.multiline : TextInputType.text),
          textCapitalization: widget.capitalizacao,
          obscureText: widget.oculto,
          maxLines: multilinha ? widget.linhas : 1,
          minLines: multilinha ? widget.linhas : null,
          onChanged: widget.aoMudar,
          textInputAction: multilinha
              ? TextInputAction.newline
              : (ultimo ? TextInputAction.done : TextInputAction.next),
          onSubmitted: multilinha
              ? null
              : (_) {
                  if (ultimo) {
                    _no.unfocus();
                  } else {
                    _registo?.seguinte(_indice);
                  }
                },
          decoration: InputDecoration(
            labelText: widget.rotulo,
            // Com o teclado aberto em paisagem, a linha de ajuda custa 20 dp —
            // um terço do campo a que pertence. Passa a `hint`: aparece
            // enquanto o campo estiver vazio, que é quando se precisa dela, e
            // não ocupa altura nenhuma. O aviso não cede o lugar a nada.
            helperText: widget.aviso ?? (apertado ? null : widget.ajuda),
            helperStyle: widget.aviso == null
                ? null
                : const TextStyle(color: Color(0xFF8A5A00)),
            helperMaxLines: 2,
            hintText: apertado && widget.aviso == null ? widget.ajuda : null,
            isDense: apertado,
          ),
        );
      },
    );
  }
}

/// A lista de campos de texto do formulário, pela ordem em que se construíram.
///
/// Guarda também o texto que cada um tinha ao nascer — é a única forma honesta
/// de responder à pergunta "há alterações por guardar?" sem obrigar cada
/// formulário a levar essa contabilidade à mão.
class RegistoDeCampos {
  final _nos = <int, FocusNode>{};
  final _controladores = <int, TextEditingController>{};
  final _inicial = <int, String>{};
  var _proximo = 0;

  /// Quantos campos há. Muda enquanto o formulário se constrói.
  final total = ValueNotifier<int>(0);

  int inscrever(FocusNode no, TextEditingController controlador) {
    final indice = _proximo++;
    _nos[indice] = no;
    _controladores[indice] = controlador;
    _inicial[indice] = controlador.text;
    controlador.addListener(_reavaliar);
    // Depois da construção: mexer num `ValueNotifier` a meio de um `build`
    // rebenta com "setState() called during build".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_morto) total.value = _nos.length;
    });
    return indice;
  }

  void riscar(int indice) {
    _nos.remove(indice);
    _controladores.remove(indice)?.removeListener(_reavaliar);
    _inicial.remove(indice);
  }

  /// Passa o foco ao campo a seguir na ordem de inscrição.
  void seguinte(int indice) {
    final seguintes = _nos.keys.where((i) => i > indice).toList()..sort();
    if (seguintes.isEmpty) return;
    _nos[seguintes.first]?.requestFocus();
  }

  /// Há texto por guardar.
  ///
  /// É um [ValueNotifier] e não um `get` porque quem pergunta é o `PopScope`, e
  /// o `canPop` que vale é o da última construção. Enquanto isto era só um
  /// getter, escrever num campo não reconstruía o ecrã: o `canPop` continuava
  /// a dizer "não há nada por guardar" e a seta de retorno saía calada, a
  /// deitar fora o que tinha acabado de ser escrito. No telemóvel passava
  /// despercebido porque o teclado a abrir provoca uma reconstrução por outra
  /// razão — bastava escrever sem que o teclado mexesse para o perder.
  final alterado = ValueNotifier<bool>(false);

  void _reavaliar() {
    if (_morto) return;
    alterado.value = _controladores.entries.any(
      (e) => e.value.text != (_inicial[e.key] ?? ''),
    );
  }

  var _morto = false;

  void dispose() {
    _morto = true;
    for (final c in _controladores.values) {
      c.removeListener(_reavaliar);
    }
    total.dispose();
    alterado.dispose();
  }
}

/// Põe o [RegistoDeCampos] ao alcance dos campos lá dentro.
class RegistoDeCamposHerdado extends InheritedWidget {
  const RegistoDeCamposHerdado({
    super.key,
    required this.registo,
    required this.apertado,
    required super.child,
  });

  final RegistoDeCampos registo;

  /// O teclado está aberto num ecrã sem altura para o comportar à vontade.
  final bool apertado;

  static RegistoDeCampos? talvezDe(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<RegistoDeCamposHerdado>()
      ?.registo;

  static bool apertadoEm(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<RegistoDeCamposHerdado>()
          ?.apertado ??
      false;

  @override
  bool updateShouldNotify(RegistoDeCamposHerdado antigo) =>
      antigo.registo != registo || antigo.apertado != apertado;
}
