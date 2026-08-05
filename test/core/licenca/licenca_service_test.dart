import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/licenca/licenca_info.dart';
import 'package:punho/core/licenca/licenca_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Regista as chamadas feitas e devolve uma resposta combinada, para não ser
/// preciso um package de mocking só por causa destes testes.
class _InvocadorFalso {
  _InvocadorFalso({this.resposta, this.erro});

  final FunctionResponse? resposta;
  final Object? erro;
  final chamadas = <({String nome, Map<String, dynamic> corpo})>[];

  Future<FunctionResponse> call(String nome, Map<String, dynamic> corpo) async {
    chamadas.add((nome: nome, corpo: corpo));
    if (erro != null) throw erro!;
    return resposta!;
  }
}

void main() {
  const machineId = 'abc123def456';

  test('validar envia app punho e o machine_id', () async {
    final invocador = _InvocadorFalso(
      resposta: const FunctionResponse(
        status: 200,
        data: {'estado': 'activa', 'plano': 'trial', 'dias_restantes': 40},
      ),
    );
    final servico = PunhoLicencaService.comInvocador(invocador.call);

    await servico.validar(machineId);

    expect(invocador.chamadas, hasLength(1));
    expect(invocador.chamadas.single.nome, 'validar-licenca');
    expect(invocador.chamadas.single.corpo['app'], 'punho');
    expect(invocador.chamadas.single.corpo['machine_id'], machineId);
  });

  test('validar converte a resposta em LicencaInfo', () async {
    final invocador = _InvocadorFalso(
      resposta: const FunctionResponse(
        status: 200,
        data: {
          'estado': 'activa',
          'plano': 'trial',
          'validade': '2026-09-03',
          'nome': 'Obras Costa',
          'nif': '123456789',
          'dias_restantes': 12,
          'oferta': true,
          'tier': 'base',
          'preferencias_features': {'relatorios': true},
        },
      ),
    );
    final servico = PunhoLicencaService.comInvocador(invocador.call);

    final licenca = await servico.validar(machineId);

    expect(licenca, isNotNull);
    expect(licenca!.estado, EstadoLicenca.activa);
    expect(licenca.funcional, isTrue);
    expect(licenca.emTrial, isTrue);
    expect(licenca.validade, DateTime(2026, 9, 3));
    expect(licenca.nome, 'Obras Costa');
    expect(licenca.diasRestantes, 12);
    expect(licenca.oferta, isTrue);
    expect(licenca.preferenciasFeatures['relatorios'], isTrue);
    // O machine_id não vem na resposta — é injectado pelo serviço.
    expect(licenca.machineId, machineId);
  });

  test('validar traz a chave mestre da empresa', () async {
    // A metade "empresa" do par; o machine_id é a do dispositivo. O Punho não
    // tem licenca.json assinado — sabe-a por aqui.
    final invocador = _InvocadorFalso(
      resposta: const FunctionResponse(
        status: 200,
        data: {
          'estado': 'activa',
          'plano': 'anual',
          'validade': '2027-09-03',
          'nif': '123456789',
          'chave_mestre': 'TRD-ABC123XYZ89',
        },
      ),
    );
    final servico = PunhoLicencaService.comInvocador(invocador.call);

    final licenca = await servico.validar(machineId);

    expect(licenca!.chaveMestre, 'TRD-ABC123XYZ89');
    expect(licenca.machineId, machineId); // o par completo
  });

  test(
    'servidor sem chave mestre (instalação antiga) → null, sem rebentar',
    () async {
      final invocador = _InvocadorFalso(
        resposta: const FunctionResponse(
          status: 200,
          data: {
            'estado': 'activa',
            'plano': 'anual',
            'validade': '2027-09-03',
          },
        ),
      );
      final servico = PunhoLicencaService.comInvocador(invocador.call);

      expect((await servico.validar(machineId))!.chaveMestre, isNull);
    },
  );

  test('validar devolve null quando a rede falha, sem excepção', () async {
    final invocador = _InvocadorFalso(erro: Exception('sem rede'));
    final servico = PunhoLicencaService.comInvocador(invocador.call);

    await expectLater(servico.validar(machineId), completion(isNull));
  });

  test('licença expirada não é funcional', () async {
    final invocador = _InvocadorFalso(
      resposta: const FunctionResponse(
        status: 200,
        data: {'estado': 'expirada', 'plano': 'trial', 'dias_restantes': 0},
      ),
    );
    final servico = PunhoLicencaService.comInvocador(invocador.call);

    final licenca = await servico.validar(machineId);

    expect(licenca!.estado, EstadoLicenca.expirada);
    expect(licenca.funcional, isFalse);
    expect(licenca.emTrial, isFalse);
  });

  test('estado desconhecido do servidor é tratado como inexistente', () async {
    final invocador = _InvocadorFalso(
      resposta: const FunctionResponse(
        status: 200,
        data: {'estado': 'qualquer-coisa-nova'},
      ),
    );
    final servico = PunhoLicencaService.comInvocador(invocador.call);

    final licenca = await servico.validar(machineId);

    expect(licenca!.estado, EstadoLicenca.inexistente);
  });

  test('resposta que não é mapa devolve null', () async {
    final invocador = _InvocadorFalso(
      resposta: const FunctionResponse(status: 200, data: 'erro interno'),
    );
    final servico = PunhoLicencaService.comInvocador(invocador.call);

    expect(await servico.validar(machineId), isNull);
  });

  test('registarTerminal envia app punho e info_host', () async {
    final invocador = _InvocadorFalso(
      resposta: const FunctionResponse(status: 200, data: {'criado': true}),
    );
    final servico = PunhoLicencaService.comInvocador(invocador.call);

    await servico.registarTerminal(machineId);

    expect(invocador.chamadas.single.nome, 'registar-terminal');
    expect(invocador.chamadas.single.corpo['app'], 'punho');
    expect(invocador.chamadas.single.corpo['machine_id'], machineId);
    expect(invocador.chamadas.single.corpo['info_host'], isA<Map>());
  });

  test('registarTerminal envia nif quando fornecido', () async {
    final invocador = _InvocadorFalso(
      resposta: const FunctionResponse(status: 200, data: {'criado': true}),
    );
    final servico = PunhoLicencaService.comInvocador(invocador.call);

    await servico.registarTerminal(machineId, nif: '509442129');

    expect(invocador.chamadas.single.corpo['nif'], '509442129');
  });

  test('registarTerminal não envia nif quando omitido', () async {
    final invocador = _InvocadorFalso(
      resposta: const FunctionResponse(status: 200, data: {'criado': true}),
    );
    final servico = PunhoLicencaService.comInvocador(invocador.call);

    await servico.registarTerminal(machineId);

    expect(invocador.chamadas.single.corpo.containsKey('nif'), isFalse);
  });

  test('registarTerminal não propaga erro de rede', () async {
    final invocador = _InvocadorFalso(erro: Exception('timeout'));
    final servico = PunhoLicencaService.comInvocador(invocador.call);

    await expectLater(servico.registarTerminal(machineId), completes);
  });
}
