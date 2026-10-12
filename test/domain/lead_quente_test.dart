import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fist/core/operations/operations_controller.dart';
import 'package:fist/data/repositories/operation_repository.dart';
import 'package:fist/domain/models/operations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **A lead quente** (César, 11 Out 2026): pessoa que nunca foi cliente, entra
/// pelo funil ou pelo Carlitos e fica para um humano validar. Traz a zona (para
/// decidir se vem ao escritório ou se vamos lá) e o nome do negócio.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Lead lead({
    String negocio = '',
    String email = '',
    String morada = '',
    String cp = '',
    String loc = '',
    LeadStatus status = LeadStatus.newLead,
    DateTime? validadaEm,
    String? cliente,
  }) => Lead(
    id: 'l1',
    name: 'Ana',
    phone: '912345678',
    status: status,
    createdAt: DateTime(2026, 10, 11),
    negocio: negocio,
    email: email,
    morada: morada,
    codigoPostal: cp,
    localidade: loc,
    validadaEm: validadaEm,
    convertedCustomerId: cliente,
  );

  group('quente', () {
    test('nova, por validar e sem cliente é quente', () {
      expect(lead().quente, isTrue);
    });
    test('validada por um humano deixa de ser quente', () {
      expect(lead(validadaEm: DateTime(2026, 10, 12)).quente, isFalse);
    });
    test('convertida em cliente deixa de ser quente', () {
      expect(lead(cliente: 'c1').quente, isFalse);
    });
    test('já qualificada não é quente', () {
      expect(lead(status: LeadStatus.qualified).quente, isFalse);
    });
  });

  group('ficha completa', () {
    test('só nome e telemóvel: 2 de 6, sem zona', () {
      final l = lead();
      expect(l.fichaCompleta, 2);
      expect(l.temZona, isFalse);
    });
    test('a zona conta com código postal ou com localidade', () {
      expect(lead(cp: '4000-001').temZona, isTrue);
      expect(lead(loc: 'Porto').temZona, isTrue);
    });
    test('tudo preenchido: 6 de 6', () {
      final l = lead(
        negocio: 'Estética Ana',
        email: 'a@b.pt',
        morada: 'Rua A, 1',
        cp: '4000-001',
      );
      expect(l.fichaCompleta, 6);
    });
  });

  test('os campos novos sobrevivem a gravar e voltar a ler', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = await PersistentOperationRepository.create();
    repo.saveLead(
      lead(negocio: 'Estética Ana', cp: '4000-001', loc: 'Porto').copyWith(
        proximaAcaoEm: DateTime(2026, 10, 13, 10),
        ultimoContactoEm: DateTime(2026, 10, 12, 9),
        ultimoContactoCanal: 'tel',
        motivoDePerda: MotivoDePerda.preco,
        validadaEm: DateTime(2026, 10, 12, 11),
        validadaPor: 'g1',
      ),
    );
    final outro = await PersistentOperationRepository.create();
    final l = outro.leads.single;
    expect(l.negocio, 'Estética Ana');
    expect(l.codigoPostal, '4000-001');
    expect(l.proximaAcaoEm, DateTime(2026, 10, 13, 10));
    expect(l.ultimoContactoCanal, 'tel');
    expect(l.motivoDePerda, MotivoDePerda.preco);
    expect(l.validadaPor, 'g1');
  });

  test('uma lead antiga, sem os campos novos, continua a abrir', () async {
    final antiga = lead();
    expect(antiga.negocio, '');
    expect(antiga.proximaAcaoEm, isNull);
    expect(antiga.motivoDePerda, isNull);
  });

  group('ações do humano', () {
    OperationsController comLead() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final controller = c.read(operationsProvider.notifier)..addLead(lead());
      return controller;
    }

    test('validar tira a lead da caixa quente e guarda quem foi', () {
      final c = comLead();
      c.validarLead('l1', 'g1', agora: DateTime(2026, 10, 12, 9));
      final l = c.state.leads.single;
      expect(l.quente, isFalse);
      expect(l.status, LeadStatus.qualified);
      expect(l.validadaPor, 'g1');
    });

    test('registar contacto marca a próxima ação para daqui a 2 dias', () {
      final c = comLead();
      c.registarContacto('l1', 'tel', agora: DateTime(2026, 10, 12, 9));
      final l = c.state.leads.single;
      expect(l.status, LeadStatus.contacted);
      expect(l.ultimoContactoCanal, 'tel');
      expect(l.proximaAcaoEm, DateTime(2026, 10, 14, 9));
    });

    test('perder exige um motivo e fica guardado', () {
      final c = comLead();
      c.perderLead('l1', MotivoDePerda.semResposta);
      final l = c.state.leads.single;
      expect(l.status, LeadStatus.lost);
      expect(l.motivoDePerda, MotivoDePerda.semResposta);
    });
  });
}
