import 'package:flutter_test/flutter_test.dart';
import 'package:punho/domain/models/workforce.dart';

/// **Um custo incompleto não é um custo: é "por apurar".**
///
/// `monthlyFleetCost` somava três parcelas que devolvem `null` de propósito
/// quando o dado falta, e transformava cada uma num zero. Um veículo com a
/// prestação declarada e o seguro e a manutenção por preencher aparecia como
/// "Custo mensal da frota: 350,00 €" — número que o gestor lê como facto
/// quando é, quando muito, um terço da conta.
///
/// A correcção separa duas perguntas que estavam a partilhar uma função:
///
///  * *"quanto custa este veículo?"* — [monthlyFleetCost]. Uma resposta
///    incompleta é uma resposta errada, por isso devolve `null`.
///  * *"quanto é que a frota já pesa na tesouraria?"* — [monthlyFleetCostKnown].
///    Aqui não contar o que falta é certo; deitar fora o que se sabe não é.
void main() {
  Vehicle veiculo({
    int? prestacao,
    int? seguro,
    InsuranceFrequency? periodicidade,
    int? manutencao,
  }) => Vehicle(
    id: 'v1',
    plate: 'XY-99-ZW',
    type: 'Carrinha',
    status: VehicleStatus.active,
    monthlyPaymentCents: prestacao,
    insuranceCents: seguro,
    insuranceFrequency: periodicidade,
    maintenanceCents: manutencao,
  );

  group('monthlyFleetCost — a pergunta "quanto custa este veículo"', () {
    test('com as três parcelas declaradas, soma-as', () {
      final v = veiculo(
        prestacao: 35000,
        seguro: 60000,
        periodicidade: InsuranceFrequency.annual,
        manutencao: 24000,
      );
      // 350,00 + 600,00/12 + 240,00/12 = 350 + 50 + 20
      expect(monthlyFleetCost(v), 42000);
    });

    test('sem seguro nem manutenção devolve null, não 350,00 €', () {
      // Era este o caso do relatório: o número aparecia inteiro e não era.
      expect(monthlyFleetCost(veiculo(prestacao: 35000)), isNull);
    });

    test('sem manutenção sozinha já chega para não haver resposta', () {
      final v = veiculo(
        prestacao: 35000,
        seguro: 60000,
        periodicidade: InsuranceFrequency.annual,
      );
      expect(monthlyFleetCost(v), isNull);
    });

    test('um seguro declarado sem periodicidade não conta como conhecido', () {
      // `monthlyInsuranceCost` já devolve null neste caso: sem saber se 600 €
      // é por mês, por semestre ou por ano, o valor não significa nada.
      final v = veiculo(prestacao: 35000, seguro: 60000, manutencao: 24000);
      expect(monthlyFleetCost(v), isNull);
    });

    test('veículo sem nada declarado é por apurar, não é grátis', () {
      expect(monthlyFleetCost(veiculo()), isNull);
    });
  });

  group('monthlyFleetCostKnown — a pergunta "quanto já pesa"', () {
    test('soma o que está declarado e ignora o que falta', () {
      // A prestação é conhecida. Dizer que este veículo pesa zero na
      // tesouraria seria pior do que subestimar.
      expect(monthlyFleetCostKnown(veiculo(prestacao: 35000)), 35000);
    });

    test('sem nada declarado, zero — que aqui é a resposta certa', () {
      expect(monthlyFleetCostKnown(veiculo()), 0);
    });

    test('com tudo declarado dá o mesmo que monthlyFleetCost', () {
      final v = veiculo(
        prestacao: 35000,
        seguro: 60000,
        periodicidade: InsuranceFrequency.annual,
        manutencao: 24000,
      );
      expect(monthlyFleetCostKnown(v), monthlyFleetCost(v));
    });
  });
}
