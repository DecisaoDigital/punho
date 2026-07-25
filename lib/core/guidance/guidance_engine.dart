import '../../domain/models/finance.dart';
import '../../domain/models/operations.dart';

enum RecommendationState { newItem, seen, accepted, ignored }

class Recommendation {
  const Recommendation({
    required this.id,
    required this.title,
    required this.explanation,
    required this.impact,
    required this.quality,
    required this.action,
    this.state = RecommendationState.newItem,
  });
  final String id, title, explanation, impact, quality, action;
  final RecommendationState state;
}

class GuidanceInput {
  const GuidanceInput({
    required this.bookings,
    required this.machines,
    required this.receipts,
    required this.expenses,
    required this.now,
  });
  final List<Booking> bookings;
  final List<Machine> machines;
  final List<Receipt> receipts;
  final List<Expense> expenses;
  final DateTime now;
}

class GuidanceEngine {
  List<Recommendation> evaluate(GuidanceInput input) {
    final result = <Recommendation>[];
    final pending = input.bookings.fold(
      0,
      (sum, b) =>
          sum +
          bookingPendingCents(b.expectedValueCents ?? 0, b.id, input.receipts),
    );
    if (pending > 0) {
      result.add(
        Recommendation(
          id: 'pending',
          title: 'Valores em atraso',
          explanation:
              'Recebeste menos dinheiro do que o previsto. Tens valores por receber em reservas.',
          impact:
              'Confirmar recebimentos e criar novas leads válidas reforça as próximas semanas.',
          quality: 'Confirmado pelos registos',
          action: 'Confirmar recebimentos e criar leads',
        ),
      );
    }
    final wednesdays = List.generate(3, (i) {
      final d = input.now.subtract(
        Duration(days: (input.now.weekday - 3) + 7 * i),
      );
      return DateTime(d.year, d.month, d.day);
    });
    final weak = wednesdays
        .where(
          (d) =>
              input.bookings
                  .where(
                    (b) =>
                        b.startsAt.year == d.year &&
                        b.startsAt.month == d.month &&
                        b.startsAt.day == d.day,
                  )
                  .length <=
              2,
        )
        .length;
    final available = input.machines
        .where((m) => !m.archived && m.status == MachineStatus.available)
        .length;
    if (weak == 3 && available > 0) {
      result.add(
        Recommendation(
          id: 'wednesday',
          title: 'Quarta-feira fraca',
          explanation:
              'Nas últimas 3 quartas-feiras tiveste apenas duas ou menos reservas. Tens $available máquinas disponíveis para a próxima quarta. 100% de zero é zero: uma máquina parada pode justificar uma promoção controlada.',
          impact:
              'Considera uma promoção de quarta-feira com até 35% de desconto.',
          quality: 'Dados de reservas e inventário identificados',
          action: 'Criar campanha',
        ),
      );
    }
    final meal = input.expenses
        .where(
          (e) =>
              e.category == ExpenseCategory.meals &&
              e.status == ExpensePaymentStatus.paid,
        )
        .fold(0, (s, e) => s + e.amountCents);
    if (meal > 0) {
      result.add(
        Recommendation(
          id: 'meals',
          title: 'Despesas de refeições',
          explanation:
              'As despesas de refeições foram ${(meal / 100).toStringAsFixed(2)} € neste período. Compara este valor com os recebimentos antes de decidir se deve ser reduzido.',
          impact: 'Acompanhar tendência.',
          quality: 'Dados de despesas',
          action: 'Ver despesas',
        ),
      );
    }
    return result;
  }
}

String availabilityLabel(List<Machine> machines, int declared) =>
    machines.where((m) => !m.archived).length < declared
    ? 'Por apurar'
    : 'Disponibilidade calculada';

enum CampaignStatus { draft, active, completed, cancelled }

class Campaign {
  const Campaign({
    required this.name,
    required this.goal,
    required this.status,
    this.discountPercent = 0,
  });
  final String name, goal;
  final CampaignStatus status;
  final int discountPercent;
}

Campaign campaignFromRecommendation(Recommendation r) => Campaign(
  name: r.title,
  goal: r.explanation,
  status: CampaignStatus.draft,
  discountPercent: r.id == 'wednesday' ? 35 : 0,
);
