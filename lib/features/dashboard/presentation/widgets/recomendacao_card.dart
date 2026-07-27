import 'package:flutter/material.dart';

import '../../../../core/guidance/guidance_engine.dart';
import 'kpi_grid_2x2.dart';

/// Cor do bordo por gravidade. Verde é convite, laranja é aviso, vermelho é
/// risco a acontecer agora. Cinza quando não há gravidade definida.
///
/// Vive aqui para a Recomendação do Dia (slide 1) e a Recomendação da Semana
/// (slide 5) usarem exactamente a mesma escala — duas escalas de cor para a
/// mesma ideia ensinariam ao gestor que a cor não quer dizer nada.
Color corDaGravidade(GravidadeRecomendacao? gravidade) => switch (gravidade) {
  GravidadeRecomendacao.oportunidade => const Color(0xFF639922),
  GravidadeRecomendacao.atencao => const Color(0xFFE0A32B),
  GravidadeRecomendacao.urgente => const Color(0xFFE24B4A),
  null => const Color(0xFF9AA5AC),
};

String etiquetaDaGravidade(GravidadeRecomendacao gravidade) =>
    switch (gravidade) {
      GravidadeRecomendacao.oportunidade => 'Oportunidade',
      GravidadeRecomendacao.atencao => 'Atenção',
      GravidadeRecomendacao.urgente => 'Urgente',
    };

/// Card de uma sugestão curta com bordo colorido e uma CTA.
///
/// Sem sugestão não desaparece: mostra a frase de vazio em cinza claro. Uma
/// célula que se esvazia muda o desenho do slide de um dia para o outro.
class RecomendacaoCard extends StatelessWidget {
  const RecomendacaoCard({
    super.key,
    required this.titulo,
    required this.gravidade,
    required this.vazio,
    this.texto,
    this.cta,
    this.aoTocarNaCta,
  });

  final String titulo;
  final GravidadeRecomendacao? gravidade;

  /// O que se mostra quando não há nada a sugerir.
  final String vazio;
  final String? texto;
  final String? cta;
  final VoidCallback? aoTocarNaCta;

  @override
  Widget build(BuildContext context) {
    final semSugestao = texto == null;
    return KpiCard(
      titulo: titulo,
      corDoBordo: semSugestao ? null : corDaGravidade(gravidade),
      rodape: semSugestao || cta == null
          ? null
          : KpiBotao(texto: cta!, onPressed: aoTocarNaCta ?? () {}),
      child: semSugestao
          ? Align(
              alignment: Alignment.centerLeft,
              child: Text(
                vazio,
                style: const TextStyle(fontSize: 15, color: Color(0xFF9AA5AC)),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (gravidade != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: corDaGravidade(gravidade).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      etiquetaDaGravidade(gravidade!),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: corDaGravidade(gravidade),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      texto!,
                      style: const TextStyle(fontSize: 14, height: 1.35),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
