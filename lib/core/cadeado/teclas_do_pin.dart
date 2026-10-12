// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

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
  final _foco = FocusNode(debugLabel: 'TeclasDoPin');

  @override
  void initState() {
    super.initState();
    // `autofocus` não chega: o cadeado vive em cima do shell, no mesmo escopo,
    // e o foco já lá estava. Pede-se à força depois do primeiro frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _foco.requestFocus();
    });
  }

  @override
  void dispose() {
    _foco.dispose();
    super.dispose();
  }

  KeyEventResult _aoTeclar(FocusNode _, KeyEvent e) {
    if (!widget.activo || e is KeyUpEvent) return KeyEventResult.ignored;
    final teclado = HardwareKeyboard.instance;
    // Ctrl/Alt/Meta são atalhos de quem os carrega; Shift+dígito é símbolo.
    if (teclado.isControlPressed ||
        teclado.isAltPressed ||
        teclado.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    final digito = TeclasDoPin._linhaDeCima[k];
    if (digito != null) {
      if (e is KeyRepeatEvent || teclado.isShiftPressed) {
        return KeyEventResult.handled;
      }
      widget.aoDigito(digito);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.backspace) {
      widget.aoApagar();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      if (e is KeyDownEvent) widget.aoConfirmar();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _foco.requestFocus(),
    child: Focus(
      focusNode: _foco,
      autofocus: true,
      onKeyEvent: _aoTeclar,
      child: widget.child,
    ),
  );
}
