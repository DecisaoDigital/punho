import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// A versão instalada, lida do `pubspec` através do `PackageInfo`.
///
/// Existe num sítio só porque já esteve em dois: o rótulo da sidebar tinha
/// `'v 0.0.13'` escrito à mão enquanto o popup de Perfil mostrava a versão a
/// sério, e a divergência passou três releases sem ninguém dar por ela.
///
/// O `Future` é estático de propósito — a versão não muda em execução, e criá-lo
/// dentro do `build` relançava a leitura a cada reconstrução do widget.
class VersaoApp extends StatelessWidget {
  const VersaoApp({
    super.key,
    required this.formato,
    this.style,
    this.textAlign,
  });

  /// Recebe a versão nua (`0.0.16`) e devolve o texto a mostrar. Cada sítio
  /// escreve-a à sua maneira: `v 0.0.16` na sidebar, `Punho v0.0.16` no perfil.
  final String Function(String versao) formato;

  final TextStyle? style;
  final TextAlign? textAlign;

  static final Future<PackageInfo> _pacote = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
    future: _pacote,
    builder: (context, snapshot) {
      final versao = snapshot.data?.version;
      // Enquanto não chega, texto vazio em vez de placeholder: o rótulo é
      // discreto e um "..." a piscar chamava mais atenção do que a versão.
      return Text(
        versao == null ? '' : formato(versao),
        textAlign: textAlign,
        style: style,
      );
    },
  );
}
