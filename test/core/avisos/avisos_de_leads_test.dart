import 'package:fist/core/avisos/avisos_de_leads.dart';
import 'package:fist/domain/models/operations.dart';
import 'package:flutter_test/flutter_test.dart';

Lead l(String id) => Lead(
  id: id,
  name: 'Lead $id',
  phone: '91$id',
  status: LeadStatus.newLead,
  createdAt: DateTime(2026, 10, 1),
);

void main() {
  test('a primeira carga nunca avisa', () {
    expect(
      leadsNovas(antes: null, agora: [l('1'), l('2')], criadasAqui: {}),
      isEmpty,
    );
  });

  test('avisa só das que não existiam e não foram escritas aqui', () {
    final novas = leadsNovas(
      antes: [l('1')],
      agora: [l('1'), l('2'), l('3')],
      criadasAqui: {'3'},
    );
    expect(novas.map((x) => x.id), ['2']);
    expect(textoDoAvisoDeLeads(novas), 'Lead nova: Lead 2');
  });

  test('uma carga em bloco não é «lead nova»', () {
    final muitas = [for (var i = 0; i < 30; i++) l('$i')];
    expect(leadsNovas(antes: [], agora: muitas, criadasAqui: {}), isEmpty);
  });

  test('plural', () {
    expect(textoDoAvisoDeLeads([l('1'), l('2')]), '2 leads novas');
  });
}
