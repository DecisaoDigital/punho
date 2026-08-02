import 'package:flutter/material.dart';

/// Diálogo de formulário com cabeçalho e rodapé fixos, corpo que rola e altura
/// que desconta o teclado.
///
/// Porque existe: os três diálogos de registo (máquina, veículo, colaborador)
/// tinham o mesmo defeito no telemóvel — o teclado abria, comia metade do ecrã
/// e o botão *Guardar* ficava debaixo dele, sem forma de chegar lá. O corpo
/// também não rolava, pelo que os últimos campos simplesmente não existiam.
///
/// A correcção é sempre a mesma, e é por isso que vive num sítio só:
///  * o corpo vai num [SingleChildScrollView] dentro de um [Flexible], por isso
///    rola quando não cabe e não estica quando cabe;
///  * o rodapé fica fora do scroll — *Guardar* está sempre visível;
///  * a altura fica limitada ao que o [Dialog] deixa, que já é o ecrã menos o
///    teclado.
///
/// O `insetPadding` **não** desconta o teclado à mão: o [Dialog] soma-lhe
/// `viewInsets` por dentro. Descontá-lo aqui contava-o duas vezes e o diálogo
/// ficava com 220 dp de altura num ecrã que tinha 532 livres.
class DialogoDeFormulario extends StatelessWidget {
  const DialogoDeFormulario({
    super.key,
    required this.titulo,
    required this.corpo,
    required this.aoGuardar,
    this.aviso,
    this.rotuloGuardar = 'Guardar',
    this.larguraMaxima = 640,
  });

  final String titulo;
  final Widget corpo;
  final VoidCallback aoGuardar;

  /// Recusa a mostrar a quem carregou em *Guardar*, logo por cima dos botões.
  ///
  /// Fica **fora** do scroll de propósito. Estas mensagens andavam em
  /// `SnackBar`, que num telemóvel deitado nasce por baixo do teclado: a
  /// gravação era recusada e o que se via era o botão a não fazer nada. Dentro
  /// do corpo também não servia — o corpo rola, e com o teclado aberto o que
  /// está à vista é o campo que tem o cursor.
  final String? aviso;

  /// O diálogo da máquina usa "Guardar e identificar" quando está a baptizar
  /// uma linha criada pelo total declarado no onboarding.
  final String rotuloGuardar;

  /// 640 dp deixa os formulários curtos mais largos em paisagem. O diálogo da
  /// máquina pede mais, porque divide os campos em duas colunas.
  final double larguraMaxima;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // O que sobra de ecrã depois do teclado. No telemóvel do Cesar deitado são
    // 393 dp de altura e o teclado leva 200 — restam 193.
    final alturaUtil = mq.size.height - mq.viewInsets.bottom;
    // Abaixo disto, a moldura fixa em tamanho normal (cabeçalho 60 dp + rodapé
    // 64) já não cabe sozinha, e o corpo — que é `Flexible` — encolhia até
    // zero: o formulário desaparecia e ficava título, vazio e botões. Medido no
    // Redmi Note 10 Pro deitado, a adicionar um colaborador.
    final apertado = alturaUtil < 320;
    final tema = Theme.of(context);
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: apertado ? 8 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: larguraMaxima),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  apertado ? 12 : 20,
                  24,
                  apertado ? 6 : 12,
                ),
                child: Text(
                  titulo,
                  style: apertado
                      ? tema.textTheme.titleMedium
                      : tema.textTheme.titleLarge,
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: corpo,
                ),
              ),
              if (aviso != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(24, apertado ? 4 : 8, 24, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 18,
                        color: tema.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          aviso!,
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: tema.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  apertado ? 6 : 12,
                  16,
                  apertado ? 6 : 12,
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: aoGuardar,
                      child: Text(rotuloGuardar),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
