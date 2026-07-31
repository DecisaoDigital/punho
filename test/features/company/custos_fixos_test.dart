import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/finance.dart';

/// Os custos fixos deixaram de ser um número redondo e passaram a rubricas.
///
/// Um total sem detalhe não se revê nem se corrige: quando a renda sobe, o
/// gestor não sabe que parte do número mudar.
void main() {
  CustoFixo rubrica(String id, ExpenseCategory c, int cents, [String d = '']) =>
      CustoFixo(id: id, categoria: c, valorCents: cents, descricao: d);

  test('sem rubricas nem total, o custo fixo é desconhecido', () {
    // `null` e não `0`: zero diria "não tens custos fixos", que é outra coisa.
    const estado = OperationsState(onboarded: true);

    expect(estado.custoFixoMensalCents, isNull);
  });

  test('o total redondo antigo continua a valer para quem só o tem', () {
    const estado = OperationsState(
      onboarded: true,
      fixedMonthlyCostsCents: 300000,
    );

    expect(estado.custoFixoMensalCents, 300000);
  });

  test('havendo rubricas, são elas que mandam', () {
    // Duas respostas para a mesma pergunta seria a app a contradizer-se.
    final estado = OperationsState(
      onboarded: true,
      fixedMonthlyCostsCents: 999999,
      custosFixos: [
        rubrica('a', ExpenseCategory.rent, 120000, 'Renda do armazém'),
        rubrica('b', ExpenseCategory.electricity, 45000),
      ],
    );

    expect(estado.custoFixoMensalCents, 165000);
  });

  test('a rubrica mostra a descrição quando existe, senão a categoria', () {
    expect(
      rubrica('a', ExpenseCategory.rent, 1, 'Renda do armazém').rotulo,
      'Renda do armazém',
    );
    expect(rubrica('b', ExpenseCategory.rent, 1).rotulo, 'Renda');
    expect(rubrica('c', ExpenseCategory.rent, 1, '   ').rotulo, 'Renda');
  });

  test('sobrevive à ida e volta por JSON', () {
    final original = rubrica('a', ExpenseCategory.cleaning, 8050, 'Semanal');

    final volta = CustoFixo.fromJson(original.toJson());

    expect(volta.id, 'a');
    expect(volta.categoria, ExpenseCategory.cleaning);
    expect(volta.valorCents, 8050);
    expect(volta.descricao, 'Semanal');
  });

  test('categoria desconhecida não rebenta a leitura do estado todo', () {
    // Uma versão mais nova pode ter categorias que esta ainda não conhece.
    final lida = CustoFixo.fromJson({
      'id': 'x',
      'categoria': 'categoria_do_futuro',
      'valorCents': 100,
    });

    expect(lida.categoria, ExpenseCategory.other);
  });

  test('a tarefa de "indicar custos fixos" some quando há rubricas', () {
    final estado = OperationsState(
      onboarded: true,
      custosFixos: [rubrica('a', ExpenseCategory.rent, 120000)],
    );

    expect(
      estado.initialDataTasks,
      isNot(contains('Indicar os custos fixos mensais')),
    );
  });
}
