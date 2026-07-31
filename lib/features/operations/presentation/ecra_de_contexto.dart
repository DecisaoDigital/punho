import 'package:flutter/material.dart';

/// Ecrã de contexto do onboarding: ícone grande, título, corpo e um só botão.
///
/// Não é um passo de dados — não pede nada, não tem "N de M". Serve para
/// explicar. O onboarding tem dois: um a dizer porque vale a pena preencher
/// mais, outro a receber o gestor antes de entrar na app.
///
/// Compõe em retrato e em paisagem: o corpo rola quando não cabe, o que importa
/// no ecrã de boas-vindas, onde o utilizador é convidado a rodar o dispositivo
/// *antes* de tocar no botão.
class EcraDeContexto extends StatelessWidget {
  const EcraDeContexto({
    super.key,
    required this.icone,
    required this.titulo,
    required this.paragrafos,
    required this.rotuloDoBotao,
    required this.aoAvancar,
    this.aoVoltar,
    this.rodape,
  });

  final IconData icone;
  final String titulo;

  /// Um `Text` por parágrafo, com respiração entre eles. Uma string só com
  /// `\n\n` lá dentro dava um bloco cinzento que ninguém lê.
  final List<String> paragrafos;

  final String rotuloDoBotao;
  final VoidCallback aoAvancar;

  /// Ausente no primeiro ecrã de um fluxo. Enquanto existir, o gestor pode
  /// voltar atrás e corrigir dados — nada foi gravado ainda.
  final VoidCallback? aoVoltar;

  /// Destaque no fundo, para o aviso da rotação.
  final Widget? rodape;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    icone,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(titulo, style: textos.headlineMedium),
                  const SizedBox(height: 16),
                  for (final paragrafo in paragrafos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(paragrafo, style: textos.bodyLarge),
                    ),
                  if (rodape != null) ...[const SizedBox(height: 8), rodape!],
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      if (aoVoltar != null)
                        TextButton(
                          onPressed: aoVoltar,
                          child: const Text('Voltar'),
                        ),
                      const Spacer(),
                      FilledButton(
                        onPressed: aoAvancar,
                        child: Text(rotuloDoBotao),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
