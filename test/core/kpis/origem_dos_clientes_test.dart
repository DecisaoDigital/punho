import 'package:flutter_test/flutter_test.dart';
import 'package:fist/core/kpis/origem_dos_clientes.dart';
import 'package:fist/core/operations/operations_controller.dart';
import 'package:fist/domain/models/operations.dart';

/// De onde vêm os contactos (César, 11 Out 2026): conta pela data de criação,
/// agrupa pela origem escolhida e vê quantos já são clientes.
void main() {
  Lead lead(
    String id,
    DateTime criada,
    LeadSource? origem, {
    bool cliente = false,
  }) => Lead(
    id: id,
    name: id,
    phone: '910000000',
    status: cliente ? LeadStatus.converted : LeadStatus.newLead,
    createdAt: criada,
    source: origem,
  );

  final out = DateTime(2026, 10, 5);
  final leads = [
    lead('a', out, LeadSource.referral, cliente: true),
    lead('b', out, LeadSource.referral),
    lead('c', out, LeadSource.landingPage),
    lead('d', out, LeadSource.ownProspecting, cliente: true),
    lead('e', out, LeadSource.whatsapp), // já não é escolha: conta como Outro
    lead('f', out, null),
    lead('g', DateTime(2026, 9, 20), LeadSource.call), // outro mês
  ];

  test('conta só o mês e agrupa por canal, do maior para o menor', () {
    final o = origemDosClientes(OperationsState(leads: leads), out);
    expect(o.contactos, 6);
    expect(o.canais.first.nome, 'Recomendação');
    expect(o.canais.first.contactos, 2);
    expect(o.canais.first.convertidos, 1);
    expect(o.canais.map((c) => c.nome), contains('Sem origem'));
    expect(o.canais.map((c) => c.nome), contains('Outro / não sei'));
    expect(o.canais.map((c) => c.nome), isNot(contains('WhatsApp')));
  });

  test('taxa e melhor canal', () {
    final o = origemDosClientes(OperationsState(leads: leads), out);
    expect(o.convertidos, 2);
    expect(o.taxa, closeTo(33.33, 0.01));
    // Empate em 1 cliente: ganha o que teve mais contactos (Recomendação, 2).
    expect(o.melhor!.nome, 'Recomendação');
  });

  test('sem contactos no mês não há taxa nem melhor canal', () {
    final o = origemDosClientes(
      OperationsState(leads: leads),
      DateTime(2026, 8, 1),
    );
    expect(o.contactos, 0);
    expect(o.taxa, isNull);
    expect(o.melhor, isNull);
  });
}
