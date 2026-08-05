import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/licenca/licenca_info.dart';
import 'package:punho/core/licenca/licenca_provider.dart';
import 'package:punho/features/licenca/presentation/diagnostico_licenca.dart';

/// O bloco "Esta instalação", no popup de perfil. Existe para responder, sem
/// adivinhar, às perguntas que aparecem quando algo não bate certo: de que
/// empresa é este aparelho, que aparelho é, e até quando vale a licença.
void main() {
  const mid =
      '339ed1626af8fc4729878db445dc79aa9cae53d6568c2c645e3aaf6315a62cac';

  Future<void> montar(WidgetTester tester, LicencaInfo? info) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          licencaProvider.overrideWith((_) async => info),
          machineIdProvider.overrideWith((_) async => mid),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: DiagnosticoLicenca()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  LicencaInfo licenca({
    String? chaveMestre,
    EstadoLicenca estado = EstadoLicenca.activa,
    String? plano = 'beta',
    int dias = 180,
  }) => LicencaInfo(
    estado: estado,
    machineId: mid,
    plano: plano,
    nif: '514287934',
    nome: 'Terraforte — Aluguer de Equipamentos',
    validade: DateTime(2027, 1, 28),
    diasRestantes: dias,
    chaveMestre: chaveMestre,
  );

  testWidgets('mostra a chave da empresa quando ela existe', (tester) async {
    await montar(tester, licenca(chaveMestre: 'TRF-Z4A9AM9QJV44'));

    expect(find.text('Esta instalação'), findsOneWidget);
    expect(find.text('TRF-Z4A9AM9QJV44'), findsOneWidget);
    expect(find.text('Terraforte — Aluguer de Equipamentos'), findsOneWidget);
    expect(find.text('514287934'), findsOneWidget);
    expect(find.text('28/01/2027'), findsOneWidget);
  });

  testWidgets('sem chave atribuída diz isso, em vez de mentir', (tester) async {
    // É o estado das instalações anteriores ao modelo do par. Uma linha vazia
    // deixava a dúvida entre "não tem" e "não carregou".
    await montar(tester, licenca());
    expect(find.text('— ainda não atribuída'), findsOneWidget);
  });

  testWidgets('o machine_id aparece encurtado — 64 caracteres não se ditam', (
    tester,
  ) async {
    await montar(tester, licenca(chaveMestre: 'TRF-Z4A9AM9QJV44'));

    expect(find.text(mid), findsNothing);
    expect(find.text('339ed162…a62cac'), findsOneWidget);
  });

  testWidgets('copiar a chave põe o valor completo na área de transferência', (
    tester,
  ) async {
    final copiado = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiado.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );

    await montar(tester, licenca(chaveMestre: 'TRF-Z4A9AM9QJV44'));
    await tester.tap(find.text('TRF-Z4A9AM9QJV44'));
    await tester.pumpAndSettle();

    expect(copiado, ['TRF-Z4A9AM9QJV44']);
  });

  testWidgets('copiar o aparelho copia o hash INTEIRO, não o encurtado', (
    tester,
  ) async {
    // O encurtado serve para ler; o que se cola tem de ser o valor real, senão
    // o que chega ao Control não corresponde a terminal nenhum.
    final copiado = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiado.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );

    await montar(tester, licenca(chaveMestre: 'TRF-Z4A9AM9QJV44'));
    await tester.tap(find.text('339ed162…a62cac'));
    await tester.pumpAndSettle();

    expect(copiado, [mid]);
  });

  testWidgets('trial mostra os dias que faltam', (tester) async {
    await montar(tester, licenca(plano: 'trial', dias: 12));
    expect(find.text('Avaliação (12 dias)'), findsOneWidget);
  });

  // Um estado por teste: remontar no mesmo teste reaproveita o `ProviderScope`
  // e as substituições continuam a ser as da primeira montagem.
  testWidgets('licença expirada di-lo', (tester) async {
    await montar(tester, licenca(estado: EstadoLicenca.expirada));
    expect(find.text('Expirada'), findsOneWidget);
  });

  testWidgets('licença suspensa di-lo', (tester) async {
    await montar(tester, licenca(estado: EstadoLicenca.inactiva));
    expect(find.text('Suspensa'), findsOneWidget);
  });

  testWidgets('sem resposta do servidor não aparece nada de errado', (
    tester,
  ) async {
    // Offline ou Supabase desligado. Isto é diagnóstico: não pode ser mais um
    // sítio a dar erro por não haver rede.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          licencaProvider.overrideWith((_) async => null),
          machineIdProvider.overrideWith((_) async => ''),
        ],
        child: const MaterialApp(home: Scaffold(body: DiagnosticoLicenca())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Esta instalação'), findsNothing);
  });
}
