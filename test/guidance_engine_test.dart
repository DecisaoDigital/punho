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
  test(
    'à segunda-feira a última quarta-feira é a de ontem-anteontem, não a da '
    'semana que vem (bug do "% 7" em falta, achado 14)',
    () {
      // 2026-08-03 é segunda-feira (weekday=1). Sem o `% 7`, `weekday - 3`
      // dá -2 e o `subtract` empurra para uma quarta-feira futura.
      final segunda = DateTime(2026, 8, 3);
      expect(segunda.weekday, DateTime.monday);
      final reserva = Booking(
        id: 'b',
        customerId: 'c',
        machineIds: const ['m'],
        // A quarta-feira anterior a esta segunda é 2026-07-29.
        startsAt: DateTime(2026, 7, 29, 9),
        endsAt: DateTime(2026, 7, 29, 11),
        status: BookingStatus.confirmed,
      );
      final semReservaNaQuartaPassada = GuidanceEngine()
          .evaluate(
            GuidanceInput(
              bookings: const [],
              machines: [
                const Machine(
                  id: 'm',
                  name: 'm',
                  reference: 'r',
                  category: 'c',
                  status: MachineStatus.available,
                ),
              ],
              receipts: const [],
              expenses: const [],
              now: segunda,
            ),
          )
          .where((x) => x.id == 'wednesday');
      final comReservaNaQuartaPassada = GuidanceEngine()
          .evaluate(
            GuidanceInput(
              bookings: [reserva, reserva, reserva],
              machines: [
                const Machine(
                  id: 'm',
                  name: 'm',
                  reference: 'r',
                  category: 'c',
                  status: MachineStatus.available,
                ),
              ],
              receipts: const [],
              expenses: const [],
              now: segunda,
            ),
          )
          .where((x) => x.id == 'wednesday');
      // Sem dados: as 3 últimas quartas (de facto passadas) contam 0
      // reservas cada uma, dispara a recomendação.
      expect(semReservaNaQuartaPassada, isNotEmpty);
      // Com 3 reservas na quarta-feira imediatamente anterior: se o código
      // estivesse a olhar (por bug) para uma quarta-feira futura, não veria
      // estas reservas e continuaria a disparar. Olhando para a quarta
      // certa, a contagem sobe acima de 2 e a recomendação não dispara.
      expect(comReservaNaQuartaPassada, isEmpty);
    },
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
