// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Teclado físico para o ecrã do PIN (Windows e qualquer sítio com teclas).
///
/// O teclado de pontos no ecrã continua a ser o principal; isto só acrescenta
/// as teclas: dígitos 0-9 da linha de cima e do bloco numérico, Backspace a
/// apagar, Enter a confirmar. Devolve `ignored` para tudo o resto, para não
/// roubar teclas (Tab, atalhos) nem campos de texto.
class TeclasDoPin extends StatefulWidget {
  const TeclasDoPin({
    super.key,
    required this.child,
    required this.aoDigito,
    required this.aoApagar,
    required this.aoConfirmar,
    this.activo = true,
  });

  final Widget child;
  final void Function(String digito) aoDigito;
  final VoidCallback aoApagar;
  final VoidCallback aoConfirmar;

  /// Falso enquanto o teclado de pontos não está à vista.
  final bool activo;

  static final _linhaDeCima = <LogicalKeyboardKey, String>{
    LogicalKeyboardKey.digit0: '0',
    LogicalKeyboardKey.digit1: '1',
    LogicalKeyboardKey.digit2: '2',
    LogicalKeyboardKey.digit3: '3',
    LogicalKeyboardKey.digit4: '4',
    LogicalKeyboardKey.digit5: '5',
    LogicalKeyboardKey.digit6: '6',
    LogicalKeyboardKey.digit7: '7',
    LogicalKeyboardKey.digit8: '8',
    LogicalKeyboardKey.digit9: '9',
    LogicalKeyboardKey.numpad0: '0',
    LogicalKeyboardKey.numpad1: '1',
    LogicalKeyboardKey.numpad2: '2',
    LogicalKeyboardKey.numpad3: '3',
    LogicalKeyboardKey.numpad4: '4',
    LogicalKeyboardKey.numpad5: '5',
    LogicalKeyboardKey.numpad6: '6',
    LogicalKeyboardKey.numpad7: '7',
    LogicalKeyboardKey.numpad8: '8',
    LogicalKeyboardKey.numpad9: '9',
  };

  @override
  State<TeclasDoPin> createState() => _TeclasDoPinState();
}

class _TeclasDoPinState extends State<TeclasDoPin> {
  @override
  void initState() {
    super.initState();
    // **Handler global do teclado, e não `Focus`.** O cadeado vive por cima do
    // shell e o foco pode estar noutro sítio (botões, o próprio shell); um
    // `Focus` só recebe teclas quando tem o foco, e na app real do Windows não
    // chegava. O `HardwareKeyboard` entrega a tecla a quem estiver registado,
    // seja qual for o foco, antes de a árvore de foco a ver.
    HardwareKeyboard.instance.addHandler(_aoTeclar);
    try {
      File('C:\\build\\pin_keys.log').writeAsStringSync('INIT\n', mode: FileMode.append);
    } catch (_) {}
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_aoTeclar);
    super.dispose();
  }

  bool _aoTeclar(KeyEvent e) {
    // DIAG-TEMPORARIO
    try {
      File('C:\\build\\pin_keys.log').writeAsStringSync('${e.runtimeType} ${e.logicalKey.keyLabel} ch=${e.character} act=${widget.activo}\n', mode: FileMode.append);
    } catch (_) {}
    if (!mounted || !widget.activo || e is KeyUpEvent) return false;
    // Se um campo de texto tem o foco (ex. recuperar palavra-passe), as teclas
    // são dele.
    final foco = FocusManager.instance.primaryFocus;
    if (foco?.context?.findAncestorWidgetOfExactType<EditableText>() != null) {
      return false;
    }
    final teclado = HardwareKeyboard.instance;
    // Ctrl/Alt/Meta são atalhos de quem os carrega; Shift+dígito é símbolo.
    if (teclado.isControlPressed ||
        teclado.isAltPressed ||
        teclado.isMetaPressed) {
      return false;
    }
    final k = e.logicalKey;
    var digito = TeclasDoPin._linhaDeCima[k];
    // Alguns teclados/layouts só trazem o carácter.
    final c = e.character;
    if (digito == null && c != null && RegExp(r'^[0-9]$').hasMatch(c)) {
      digito = c;
    }
    if (digito != null) {
      if (e is KeyDownEvent && !teclado.isShiftPressed) widget.aoDigito(digito);
      return true;
    }
    if (k == LogicalKeyboardKey.backspace) {
      widget.aoApagar();
      return true;
    }
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      if (e is KeyDownEvent) widget.aoConfirmar();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
