import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:punho/core/updates/update_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Os testes usam `PunhoUpdateService.comInvocador`, que não tem cliente
/// Supabase — logo não tem sessão. É de propósito: o cenário a proteger é o do
/// utilizador que nunca entrou (preso no login) ou que está bloqueado no gate.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    PackageInfo.setMockInitialValues(
      appName: 'Punho',
      packageName: 'pt.decisaodigital.punho',
      version: '0.0.2',
      buildNumber: '2',
      buildSignature: '',
    );
  });

  group('check() sem sessão', () {
    test('devolve o update quando o servidor diz que há versão nova', () async {
      final servico = PunhoUpdateService.comInvocador(
        (corpo, cabecalhos) async => const FunctionResponse(
          status: 200,
          data: {
            'actualizacao_disponivel': true,
            'versao_actual': '0.0.4',
            'build_number': 9,
            'url_download': 'https://exemplo/punho-0.0.4.apk',
            'obrigatoria': false,
            'notas_lancamento': 'Aviso de update em qualquer ecrã.',
          },
        ),
      );

      final info = await servico.check();

      expect(info, isNotNull);
      expect(info!.version, '0.0.4');
      expect(info.buildNumber, 9);
      expect(info.downloadUrl, 'https://exemplo/punho-0.0.4.apk');
      expect(info.mandatory, isFalse);
    });

    test('sem sessão não manda header de Authorization', () async {
      // A Edge Function é chamada com a chave pública que o supabase_flutter já
      // envia. Mandar um `Bearer null` era como o antigo código se enganava.
      Map<String, String>? recebidos = {'ainda': 'nao chamado'};
      Map<String, dynamic>? corpoRecebido;
      final servico = PunhoUpdateService.comInvocador((
        corpo,
        cabecalhos,
      ) async {
        recebidos = cabecalhos;
        corpoRecebido = corpo;
        return const FunctionResponse(
          status: 200,
          data: {'actualizacao_disponivel': false},
        );
      });

      await servico.check();

      expect(recebidos, isNull);
      expect(corpoRecebido?['app'], 'punho');
      expect(corpoRecebido?['build_number_local'], 2);
    });

    test('devolve null quando o servidor diz que não há update', () async {
      final servico = PunhoUpdateService.comInvocador(
        (corpo, cabecalhos) async => const FunctionResponse(
          status: 200,
          data: {'actualizacao_disponivel': false},
        ),
      );

      expect(await servico.check(), isNull);
    });

    test('devolve null e cala-se quando a chamada rebenta', () async {
      final servico = PunhoUpdateService.comInvocador(
        (corpo, cabecalhos) async => throw Exception('sem rede'),
      );

      expect(await servico.check(), isNull);
    });

    test('devolve null quando a resposta não é um mapa', () async {
      final servico = PunhoUpdateService.comInvocador(
        (corpo, cabecalhos) async =>
            const FunctionResponse(status: 500, data: 'Internal Server Error'),
      );

      expect(await servico.check(), isNull);
    });

    test('update obrigatório chega marcado como obrigatório', () async {
      final servico = PunhoUpdateService.comInvocador(
        (corpo, cabecalhos) async => const FunctionResponse(
          status: 200,
          data: {
            'actualizacao_disponivel': true,
            'versao_actual': '0.0.5',
            'build_number': 10,
            'url_download': 'https://exemplo/punho-0.0.5.apk',
            'obrigatoria': true,
          },
        ),
      );

      final info = await servico.check();

      expect(info?.mandatory, isTrue);
      expect(info?.releaseNotes, isNull);
    });
  });
}
