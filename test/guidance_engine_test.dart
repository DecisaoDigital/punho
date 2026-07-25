import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/guidance/guidance_engine.dart';
import 'package:punho/domain/models/operations.dart';

void main() {
  final now = DateTime(2026, 7, 30);
  GuidanceInput data({
    List<Booking> b = const [],
    List<Machine> m = const [],
  }) => GuidanceInput(
    bookings: b,
    machines: m,
    receipts: const [],
    expenses: const [],
    now: now,
  );
  test(
    'disponibilidade insuficiente não gera promoção',
    () => expect(
      GuidanceEngine().evaluate(data()).where((x) => x.id == 'wednesday'),
      isEmpty,
    ),
  );
  test(
    'três quartas fracas geram recomendação com capacidade',
    () => expect(
      GuidanceEngine()
          .evaluate(
            data(
              m: [
                const Machine(
                  id: 'm',
                  name: 'm',
                  reference: 'r',
                  category: 'c',
                  status: MachineStatus.available,
                ),
              ],
            ),
          )
          .where((x) => x.id == 'wednesday'),
      isNotEmpty,
    ),
  );
  test('campanha de sugestão fica rascunho', () {
    final c = campaignFromRecommendation(
      const Recommendation(
        id: 'wednesday',
        title: 'x',
        explanation: 'x',
        impact: 'x',
        quality: 'x',
        action: 'x',
      ),
    );
    expect(c.status, CampaignStatus.draft);
  });
  test(
    'dados incompletos mostram por apurar',
    () => expect(availabilityLabel(const [], 15), 'Por apurar'),
  );

  test('frase semanal tem autor e contexto de aplicação', () {
    final note = weeklyManagementNote(DateTime(2026, 7, 30));
    expect(note.author, isNotEmpty);
    expect(note.context, isNotEmpty);
  });

  test('objectivo semanal mede a recomendação principal', () {
    const recommendation = Recommendation(
      id: 'test',
      title: 'Melhorar cobrança',
      explanation: 'Há valores pendentes.',
      impact: 'Mais tesouraria.',
      quality: 'Dados confirmados.',
      action: 'Contactar clientes',
      measure: 'Valor por receber no fim da semana.',
    );
    final goal = weeklyGoalFromRecommendations([recommendation]);
    expect(goal.title, 'Melhorar cobrança');
    expect(goal.measure, 'Valor por receber no fim da semana.');
  });
}
