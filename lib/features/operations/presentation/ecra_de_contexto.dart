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
  /// O lado do ícone — e do símbolo, que ocupa o mesmo lugar.
  static const _ladoDoTopo = 56.0;

  const EcraDeContexto({
    super.key,
    this.icone,
    this.simbolo,
    required this.titulo,
    required this.paragrafos,
    required this.rotuloDoBotao,
    required this.aoAvancar,
    this.aoVoltar,
    this.rodape,
  }) : assert(
         (icone == null) != (simbolo == null),
         'ou um ícone do Material ou um símbolo nosso — o topo é um só',
       );

  /// Um ícone do Material, para o que é conceito: um visto, um aviso.
  final IconData? icone;

  /// A marca, para quando quem abre o ecrã é a marca. Ocupa o mesmo lugar do
  /// [icone] e mede o mesmo, para o ritmo do ecrã não mudar consoante o que lá
  /// está.
  final Widget? simbolo;

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
                  simbolo ??
                      Icon(
                        icone,
                        size: _ladoDoTopo,
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
