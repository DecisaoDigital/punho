import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/empresa_sync/empresa_sync_controller.dart';
import 'package:punho/core/empresa_sync/empresa_sync_service.dart';
import 'package:punho/core/empresa_sync/ficha_pendente.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A política de "guardar e insistir", sem Timer nem WidgetsBinding — o que
/// aqui se testa é directamente o [EmpresaSyncEngine], como o `_tentar` do
/// [EmpresaSyncController] o chamaria de 20 em 20 minutos. Chamar `tentarEnviar`
/// à mão é o "injectar o tempo": em vez de esperar 20 minutos a sério, o
/// temporizador é o que se está a simular, não o motor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FichaEmpresaPendente pendente;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    pendente = FichaEmpresaPendente(await SharedPreferences.getInstance());
  });

  test('sem ficha pendente, tentarEnviar não liga a rede', () async {
    var chamou = false;
    final motor = EmpresaSyncEngine(
      sync: EmpresaSyncService.mock((_) async {
        chamou = true;
        return {'ok': true};
      }),
      pendente: pendente,
    );

    await motor.tentarEnviar();

    expect(chamou, isFalse);
  });

  test('quando o servidor confirma (ok == true), a pendência é limpa', () async {
    final motor = EmpresaSyncEngine(
      sync: EmpresaSyncService.mock((_) async => {'ok': true}),
      pendente: pendente,
    );

    await motor.atualizarFicha({
      'nif': '509442129',
      'nome_comercial': 'Mare Alta',
    });

    expect(
      pendente.ficha,
      isNull,
      reason: 'o servidor confirmou, não há o que reter',
    );
  });

  test('quando o servidor não confirma, a pendência mantém-se', () async {
    final motor = EmpresaSyncEngine(
      sync: EmpresaSyncService.mock((_) async => {'ok': false}),
      pendente: pendente,
    );

    await motor.atualizarFicha({'nif': '509442129'});

    expect(pendente.ficha, {'nif': '509442129'});
  });

  test('uma resposta inesperada da EF também mantém a pendência', () async {
    final motor = EmpresaSyncEngine(
      sync: EmpresaSyncService.mock((_) async => {'algo': 'estranho'}),
      pendente: pendente,
    );

    await motor.atualizarFicha({'nif': '509442129'});

    expect(pendente.ficha, isNotNull);
  });

  test('uma excepção na chamada (sem rede) mantém a pendência, sem lançar', () async {
    final motor = EmpresaSyncEngine(
      sync: EmpresaSyncService.mock((_) async => throw Exception('sem rede')),
      pendente: pendente,
    );

    await motor.atualizarFicha({'nif': '509442129'});

    expect(pendente.ficha, {'nif': '509442129'});
  });

  test(
    'uma ficha mais recente substitui a anterior, mesmo com a antiga por enviar',
    () async {
      final motor = EmpresaSyncEngine(
        sync: EmpresaSyncService.mock((_) async => {'ok': false}),
        pendente: pendente,
      );

      await motor.atualizarFicha({'nif': '111', 'nome_comercial': 'Primeira'});
      await motor.atualizarFicha({'nif': '222', 'nome_comercial': 'Segunda'});

      expect(pendente.ficha, {'nif': '222', 'nome_comercial': 'Segunda'});
    },
  );

  test('retentar mais tarde entrega a ficha que tinha ficado pendente', () async {
    var tentativas = 0;
    final motor = EmpresaSyncEngine(
      sync: EmpresaSyncService.mock((_) async {
        tentativas++;
        // Só confirma na segunda tentativa — simula a rede a voltar depois
        // dos primeiros 20 minutos.
        return {'ok': tentativas > 1};
      }),
      pendente: pendente,
    );

    await motor.atualizarFicha({'nif': '509442129'});
    expect(pendente.ficha, isNotNull, reason: 'a primeira tentativa falhou');

    // O que o temporizador do EmpresaSyncController faria de 20 em 20
    // minutos — aqui chamado directamente, sem esperar o tempo a sério.
    await motor.tentarEnviar();

    expect(pendente.ficha, isNull, reason: 'a segunda tentativa confirmou');
    expect(tentativas, 2);
  });

  test('a pendência sobrevive a uma instância nova do motor', () async {
    final motorAntigo = EmpresaSyncEngine(
      sync: EmpresaSyncService.mock((_) async => {'ok': false}),
      pendente: pendente,
    );
    await motorAntigo.atualizarFicha({'nif': '509442129'});

    // Como no arranque seguinte: nova leitura do SharedPreferences, novo
    // motor, e a ficha continua lá para se tentar outra vez.
    final pendenteNova = FichaEmpresaPendente(
      await SharedPreferences.getInstance(),
    );
    var chegou = false;
    final motorNovo = EmpresaSyncEngine(
      sync: EmpresaSyncService.mock((args) async {
        chegou =
            (args['dados'] as Map)['nif'] == '509442129';
        return {'ok': true};
      }),
      pendente: pendenteNova,
    );

    await motorNovo.tentarEnviar();

    expect(chegou, isTrue);
    expect(pendenteNova.ficha, isNull);
  });
}
