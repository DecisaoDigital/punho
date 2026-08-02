import '../../domain/models/finance.dart';
import '../../domain/models/operations.dart';

enum RecommendationState { newItem, seen, accepted, ignored }

enum GuidanceLever {
  demand('Procura e vendas'),
  cash('Tesouraria'),
  margin('Margem'),
  utilization('Utilização da frota'),
  team('Equipa e processo');

  const GuidanceLever(this.label);
  final String label;
}

/// Quanto é que a recomendação aperta. Dá a cor do bordo do card no painel.
enum GravidadeRecomendacao {
  /// Há dinheiro a fazer. Verde: é convite, não aviso.
  oportunidade(0),

  /// Algo a melhorar, sem urgência. Laranja.
  atencao(1),

  /// Risco financeiro ou operacional imediato. Vermelho.
  urgente(2);

  const GravidadeRecomendacao(this.prioridade);

  /// Ordem de apresentação: o painel mostra **uma** recomendação, e é a mais
  /// grave que está por resolver.
  final int prioridade;
}

class Recommendation {
  const Recommendation({
    required this.id,
    required this.title,
    required this.explanation,
    required this.impact,
    required this.quality,
    required this.action,
    this.measure = 'Confirma o resultado depois de executar a ação.',
    this.lever = GuidanceLever.utilization,
    this.state = RecommendationState.newItem,
    this.gravidade = GravidadeRecomendacao.atencao,
  });
  final String id, title, explanation, impact, quality, action, measure;
  final GuidanceLever lever;
  final RecommendationState state;

  /// Por omissão `atencao`: uma recomendação sem gravidade atribuída não deve
  /// passar por oportunidade nem alarmar como urgente.
  final GravidadeRecomendacao gravidade;
}

class WeeklyManagementNote {
  const WeeklyManagementNote({
    required this.text,
    required this.author,
    required this.source,
    required this.context,
    this.isDirectQuote = false,
  });
  final String text;
  final String author;
  final String source;
  final String context;
  final bool isDirectQuote;
}

class WeeklyGoal {
  const WeeklyGoal({
    required this.title,
    required this.action,
    required this.measure,
  });
  final String title;
  final String action;
  final String measure;
}

const _weeklyNotes = [
  WeeklyManagementNote(
    text:
        'No passado, o homem vinha primeiro; no futuro, o sistema tem de vir primeiro.',
    author: 'Frederick W. Taylor',
    source: 'The Principles of Scientific Management, 1911',
    isDirectQuote: true,
    context:
        'Um bom processo protege a equipa de depender apenas de memória, urgência ou improviso.',
  ),
  WeeklyManagementNote(
    text: 'O consumo é o único fim e propósito de toda a produção.',
    author: 'Adam Smith',
    source: 'The Wealth of Nations, 1776',
    isDirectQuote: true,
    context:
        'Máquinas, preço e rapidez só têm valor quando tornam a vida do cliente melhor.',
  ),
  WeeklyManagementNote(
    text: 'Foca primeiro os poucos factores que concentram o maior impacto.',
    author: 'Vilfredo Pareto',
    source: 'Princípio de concentração de impacto',
    context:
        'Procura os clientes, máquinas ou despesas que mais movem os resultados antes de dispersar esforço.',
  ),
  WeeklyManagementNote(
    text: 'Inovar é testar uma forma melhor de criar valor.',
    author: 'Joseph Schumpeter',
    source: 'Ideia aplicada de desenvolvimento e inovação',
    context:
        'Uma campanha ou novo serviço deve ser um teste com objectivo e medida, não uma aposta às cegas.',
  ),
  WeeklyManagementNote(
    text:
        'Os problemas resolvem-se melhor quando quem está no terreno participa na solução.',
    author: 'Mary Parker Follett',
    source: 'Ideia aplicada de Creative Experience, 1924',
    context:
        'O colaborador vê atrasos, avarias e pedidos do cliente; registar essa informação melhora a decisão do gestor.',
  ),
];

WeeklyManagementNote weeklyManagementNote(DateTime date) {
  final anchor = DateTime(2026, 1, 5);
  final index = date.difference(anchor).inDays ~/ 7;
  return _weeklyNotes[index.abs() % _weeklyNotes.length];
}

WeeklyGoal weeklyGoalFromRecommendations(List<Recommendation> recommendations) {
  if (recommendations.isEmpty) {
    return const WeeklyGoal(
      title: 'Criar base de gestão',
      action:
          'Regista esta semana pelo menos uma reserva, um recebimento e uma despesa.',
      measure:
          'No fim da semana confirma se já tens números suficientes para o Punho orientar.',
    );
  }
  final recommendation = recommendations.first;
  return WeeklyGoal(
    title: recommendation.title,
    action: recommendation.action,
    measure: recommendation.measure,
  );
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
          measure: 'Compara o valor por receber no início e no fim da semana.',
          lever: GuidanceLever.cash,
          // Dinheiro que já era da empresa e não entrou: é o que aperta mais.
          gravidade: GravidadeRecomendacao.urgente,
        ),
      );
    }
    // `weekday - 3` dá a última quarta-feira só quando é positivo. Às
    // segundas (1) e terças (2) fica negativo e `subtract` empurra para uma
    // quarta-feira que ainda não aconteceu — as "últimas 3 quartas" saíam
    // todas uma semana à frente. O `% 7` mantém sempre a última quarta-feira
    // já passada (ou hoje, se hoje for quarta).
    final wednesdays = List.generate(3, (i) {
      final d = input.now.subtract(
        Duration(days: (input.now.weekday - 3) % 7 + 7 * i),
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
          measure:
              'Compara reservas, receita e margem com uma quarta-feira normal.',
          lever: GuidanceLever.demand,
          // Máquina parada é receita que não se faz, não é prejuízo a acontecer.
          gravidade: GravidadeRecomendacao.oportunidade,
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
          measure: 'Compara refeições com os recebimentos do mesmo período.',
          lever: GuidanceLever.margin,
          gravidade: GravidadeRecomendacao.atencao,
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
