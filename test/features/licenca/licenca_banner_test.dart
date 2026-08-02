import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/licenca/licenca_info.dart';
import 'package:punho/core/licenca/licenca_provider.dart';
import 'package:punho/core/licenca/licenca_service.dart';
import 'package:punho/features/licenca/presentation/licenca_banner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

LicencaInfo _licenca(
  EstadoLicenca estado, {
  String? plano = 'trial',
  int dias = 40,
}) => LicencaInfo(
  estado: estado,
  machineId: 'abc123def456',
  plano: plano,
  diasRestantes: dias,
);

/// Conta os registos pedidos pelo banner quando o estado é `inexistente`.
class _ServicoEspiao extends PunhoLicencaService {
  _ServicoEspiao() : super.comInvocador(_semRede);

  static Future<FunctionResponse> _semRede(String _, Map<String, dynamic> _) =>
      throw Exception('sem rede');

  final registos = <String>[];

  @override
  Future<void> registarTerminal(String machineId, {String? nif}) async {
    registos.add(machineId);
  }
}

Future<void> _montar(
  WidgetTester tester,
  LicencaInfo? licenca, {
  PunhoLicencaService? servico,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        licencaProvider.overrideWith((ref) async => licenca),
        if (servico != null)
          licencaServiceProvider.overrideWithValue(servico),
      ],
      child: const MaterialApp(
        home: Scaffold(body: LicencaBanner()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Color? _corDoCartao(WidgetTester tester) =>
    tester.widget<Card>(find.byType(Card)).color;

void main() {
  group('avisoParaLicenca', () {
    test('sem informação não há aviso', () {
      expect(avisoParaLicenca(null), isNull);
    });

    test('trial com folga não gera aviso', () {
      expect(
        avisoParaLicenca(_licenca(EstadoLicenca.activa, dias: 40)),
        isNull,
      );
    });

    test('plano pago activo não gera aviso mesmo com poucos dias', () {
      expect(
        avisoParaLicenca(
          _licenca(EstadoLicenca.activa, plano: 'mensal', dias: 2),
        ),
        isNull,
      );
    });

    test('fronteira dos 10 dias: 11 não avisa, 10 avisa', () {
      expect(
        avisoParaLicenca(_licenca(EstadoLicenca.activa, dias: 11)),
        isNull,
      );
      expect(
        avisoParaLicenca(_licenca(EstadoLicenca.activa, dias: 10)),
        isNotNull,
      );
    });

    test('singular do dia é respeitado', () {
      final aviso = avisoParaLicenca(_licenca(EstadoLicenca.activa, dias: 1));
      expect(aviso!.mensagem, contains('1 dia'));
      expect(aviso.mensagem, isNot(contains('1 dias')));
    });
  });

  group('LicencaBanner', () {
    testWidgets('licença folgada não mostra nada', (tester) async {
      await _montar(tester, _licenca(EstadoLicenca.activa, dias: 40));
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('trial a 3 dias mostra aviso laranja', (tester) async {
      await _montar(tester, _licenca(EstadoLicenca.activa, dias: 3));

      expect(find.textContaining('3 dias'), findsOneWidget);
      expect(find.textContaining('contactar já'), findsOneWidget);
      expect(_corDoCartao(tester), const Color(0xFFF8C98A));
    });

    testWidgets('trial a 8 dias mostra aviso amarelo', (tester) async {
      await _montar(tester, _licenca(EstadoLicenca.activa, dias: 8));

      expect(find.textContaining('8 dias'), findsOneWidget);
      expect(_corDoCartao(tester), const Color(0xFFFFE9B8));
    });

    testWidgets('licença expirada mostra aviso vermelho e botão', (
      tester,
    ) async {
      await _montar(tester, _licenca(EstadoLicenca.expirada, dias: 0));

      expect(find.textContaining('expirada'), findsOneWidget);
      expect(find.text('Contactar'), findsOneWidget);
      expect(_corDoCartao(tester), const Color(0xFFF8CFCB));
    });

    testWidgets('licença suspensa mostra aviso vermelho', (tester) async {
      await _montar(tester, _licenca(EstadoLicenca.inactiva, dias: 0));

      expect(find.textContaining('suspensa'), findsOneWidget);
      expect(_corDoCartao(tester), const Color(0xFFF8CFCB));
    });

    testWidgets('terminal por registar fica cinzento e tenta o registo', (
      tester,
    ) async {
      final servico = _ServicoEspiao();
      await _montar(
        tester,
        _licenca(EstadoLicenca.inexistente, dias: 0),
        servico: servico,
      );

      expect(find.textContaining('por registar'), findsOneWidget);
      expect(_corDoCartao(tester), const Color(0xFFE2E7EC));
      expect(servico.registos, ['abc123def456']);
    });

    testWidgets('o registo não é repetido em cada rebuild', (tester) async {
      final servico = _ServicoEspiao();
      await _montar(
        tester,
        _licenca(EstadoLicenca.inexistente, dias: 0),
        servico: servico,
      );
      await tester.pumpAndSettle();

      expect(servico.registos, hasLength(1));
    });
  });
}
