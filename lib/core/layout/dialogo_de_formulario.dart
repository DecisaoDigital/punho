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
///  * `insetPadding` desconta `viewInsets.bottom` — o diálogo sobe com o teclado;
///  * `maxHeight` desconta o mesmo — o diálogo encolhe em vez de transbordar;
///  * o corpo vai num [SingleChildScrollView] dentro de um [Flexible], por isso
///    rola quando não cabe e não estica quando cabe;
///  * o rodapé fica fora do scroll — *Guardar* está sempre visível.
class DialogoDeFormulario extends StatelessWidget {
  const DialogoDeFormulario({
    super.key,
    required this.titulo,
    required this.corpo,
    required this.aoGuardar,
    this.rotuloGuardar = 'Guardar',
    this.larguraMaxima = 560,
  });

  final String titulo;
  final Widget corpo;
  final VoidCallback aoGuardar;

  /// O diálogo da máquina usa "Guardar e identificar" quando está a baptizar
  /// uma linha criada pelo total declarado no onboarding.
  final String rotuloGuardar;

  /// 560 dp serve um formulário de uma coluna. O diálogo da máquina pede mais,
  /// porque em paisagem divide os campos em duas colunas.
  final double larguraMaxima;

  @override
  Widget build(BuildContext context) {
    final teclado = MediaQuery.viewInsetsOf(context).bottom;
    final alturaDoEcra = MediaQuery.sizeOf(context).height;
    return Dialog(
      insetPadding: EdgeInsets.fromLTRB(16, 24, 16, teclado + 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: larguraMaxima,
          // Sem descontar o teclado o diálogo tenta ocupar o ecrã inteiro e
          // rebenta pelo fundo em vez de rolar.
          maxHeight: (alturaDoEcra - teclado - 48).clamp(160.0, alturaDoEcra),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Text(
                titulo,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: corpo,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
    );
  }
}
