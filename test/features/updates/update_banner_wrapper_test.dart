import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/updates/update_info.dart';
import 'package:punho/features/auth/acesso_providers.dart';
import 'package:punho/features/auth/domain/estado_acesso.dart';
import 'package:punho/features/auth/presentation/acesso_indisponivel_screen.dart';
import 'package:punho/features/auth/presentation/auth_gate.dart';
import 'package:punho/features/auth/presentation/pedido_em_analise_screen.dart';
import 'package:punho/features/collaborator/presentation/collaborator_shell.dart';
import 'package:punho/features/shell/presentation/app_shell.dart';
import 'package:punho/features/updates/presentation/update_banner.dart';
import 'package:punho/features/updates/presentation/update_banner_wrapper.dart';
import 'package:punho/features/updates/update_providers.dart';

import '../auth/fake_acesso_service.dart';

const _opcional = PunhoUpdateInfo(
  version: '0.0.4',
  buildNumber: 9,
  downloadUrl: 'https://exemplo/punho-0.0.4.apk',
  mandatory: false,
);

const _obrigatorio = PunhoUpdateInfo(
  version: '0.0.5',
  buildNumber: 10,
  downloadUrl: 'https://exemplo/punho-0.0.5.apk',
  mandatory: true,
);

const _opcionalNovo = PunhoUpdateInfo(
  version: '0.0.6',
  buildNumber: 11,
  downloadUrl: 'https://exemplo/punho-0.0.6.apk',
  mandatory: false,
);

/// Estado de update fixo, sem rede e sem `Supabase.instance`.
class _UpdateFixo extends PunhoUpdateController {
  _UpdateFixo(this.info);
  final PunhoUpdateInfo? info;

  @override
  PunhoUpdateInfo? build() => info;
}

Future<void> _montar(
  WidgetTester tester, {
  required Widget child,
  PunhoUpdateInfo? update,
  FakeAcessoService? acesso,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        punhoUpdateProvider.overrideWith(() => _UpdateFixo(update)),
        if (acesso != null) acessoServiceProvider.overrideWithValue(acesso),
      ],
      child: MaterialApp(home: PunhoUpdateBannerWrapper(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

/// Ecrã de teste com um botão que conta toques — serve para provar que o update
/// obrigatório bloqueia mesmo o que está por baixo.
class _AlvoDeToque extends StatelessWidget {
  const _AlvoDeToque({required this.aoToque});
  final VoidCallback aoToque;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(onPressed: aoToque, child: const Text('Continuar')),
    ),
  );
}

Finder get _avisoOpcional => find.text('Nova versão 0.0.4 disponível');
Finder get _avisoObrigatorio => find.text('Atualização obrigatória disponível');

void main() {
  group('O aviso de update aparece em qualquer ecrã', () {
    testWidgets('no gate com pedido em análise', (tester) async {
      final fake = FakeAcessoService(
        acesso: const EstadoAcesso(membroAtivo: false, estado: 'pendente'),
      );
      await _montar(
        tester,
        child: const AcessoGate(),
        update: _opcional,
        acesso: fake,
      );

      expect(find.byType(PedidoEmAnaliseScreen), findsOneWidget);
      expect(_avisoOpcional, findsOneWidget);
      // O gate continua a mandar: o aviso não abre a app a quem não tem acesso.
      expect(find.byType(AppShell), findsNothing);
    });

    testWidgets('no gate com acesso recusado ou revogado', (tester) async {
      for (final estado in ['recusado', 'revogado']) {
        final fake = FakeAcessoService(
          acesso: EstadoAcesso(membroAtivo: false, estado: estado),
        );
        await _montar(
          tester,
          child: const AcessoGate(),
          update: _opcional,
          acesso: fake,
        );

        expect(
          find.byType(AcessoIndisponivelScreen),
          findsOneWidget,
          reason: estado,
        );
        expect(_avisoOpcional, findsOneWidget, reason: estado);
        expect(find.byType(AppShell), findsNothing, reason: estado);
      }
    });

    testWidgets('na shell de gestor', (tester) async {
      await _montar(tester, child: const AppShell(), update: _opcional);

      expect(find.byType(AppShell), findsOneWidget);
      expect(_avisoOpcional, findsOneWidget);
    });

    testWidgets('na shell de colaborador', (tester) async {
      await _montar(
        tester,
        child: const CollaboratorShell(
          collaboratorId: 'collab-a',
          titulo: 'Colaborador',
        ),
        update: _opcional,
      );

      expect(find.byType(CollaboratorShell), findsOneWidget);
      expect(_avisoOpcional, findsOneWidget);
    });
  });

  group('Sem update não há aviso', () {
    testWidgets('o wrapper devolve o ecrã intacto', (tester) async {
      final fake = FakeAcessoService(
        acesso: const EstadoAcesso(membroAtivo: false, estado: 'pendente'),
      );
      await _montar(tester, child: const AcessoGate(), acesso: fake);

      expect(find.byType(PedidoEmAnaliseScreen), findsOneWidget);
      expect(find.byType(PunhoUpdateBanner), findsNothing);
      expect(find.textContaining('disponível'), findsNothing);
    });
  });

  group('Update obrigatório', () {
    testWidgets('bloqueia a interacção com o ecrã por baixo', (tester) async {
      var toques = 0;
      await _montar(
        tester,
        child: _AlvoDeToque(aoToque: () => toques++),
        update: _obrigatorio,
      );

      expect(_avisoObrigatorio, findsOneWidget);
      // warnIfMissed: false — o ponto do teste é precisamente o toque não
      // chegar ao botão, que está atrás da barreira.
      await tester.tap(find.text('Continuar'), warnIfMissed: false);
      await tester.pump();

      expect(toques, 0);
      expect(find.byKey(barreiraUpdateObrigatorio), findsOneWidget);
    });

    testWidgets('não tem forma de ser dispensado', (tester) async {
      await _montar(tester, child: const AppShell(), update: _obrigatorio);

      expect(_avisoObrigatorio, findsOneWidget);
      expect(find.text('Atualizar'), findsOneWidget);
      expect(find.text('Mais tarde'), findsNothing);
      expect(find.text('Dispensar'), findsNothing);
      // Tocar na barreira não a fecha.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(_avisoObrigatorio, findsOneWidget);
    });

    testWidgets('bloqueia também quem está preso no gate', (tester) async {
      final fake = FakeAcessoService(
        acesso: const EstadoAcesso(membroAtivo: false, estado: 'pendente'),
      );
      await _montar(
        tester,
        child: const AcessoGate(),
        update: _obrigatorio,
        acesso: fake,
      );

      expect(_avisoObrigatorio, findsOneWidget);
      await tester.tap(find.text('Terminar sessão'), warnIfMissed: false);
      await tester.pump();
      expect(fake.sessoesTerminadas, 0);
    });
  });

  group('Update opcional', () {
    testWidgets('empurra o conteúdo mas não lhe rouba os toques', (
      tester,
    ) async {
      var toques = 0;
      await _montar(
        tester,
        child: _AlvoDeToque(aoToque: () => toques++),
        update: _opcional,
      );

      await tester.tap(find.text('Continuar'));
      await tester.pump();

      expect(toques, 1);
      expect(_avisoOpcional, findsOneWidget);
      expect(find.byKey(barreiraUpdateObrigatorio), findsNothing);
    });
  });

  group('Update opcional pode ser dispensado', () {
    testWidgets('o X esconde o aviso sem tocar no ecrã de baixo', (
      tester,
    ) async {
      var toques = 0;
      final container = ProviderContainer(
        overrides: [
          punhoUpdateProvider.overrideWith(() => _UpdateFixo(_opcional)),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: PunhoUpdateBannerWrapper(
              child: _AlvoDeToque(aoToque: () => toques++),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_avisoOpcional, findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(_avisoOpcional, findsNothing);
      expect(find.byType(PunhoUpdateBanner), findsNothing);
      // O ecrã de baixo continua lá e continua a receber toques.
      await tester.tap(find.text('Continuar'));
      await tester.pump();
      expect(toques, 1);
    });

    testWidgets('o obrigatório não tem X — não há forma de o calar', (
      tester,
    ) async {
      await _montar(tester, child: const AppShell(), update: _obrigatorio);

      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets(
      'dispensar uma versão não esconde uma versão mais recente que apareça a seguir',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            punhoUpdateProvider.overrideWith(() => _UpdateFixo(_opcional)),
          ],
        );
        addTearDown(container.dispose);
        container.read(updateDispensadoProvider.notifier).state =
            _opcional.buildNumber;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: PunhoUpdateBannerWrapper(child: SizedBox()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(_avisoOpcional, findsNothing);

        container.read(punhoUpdateProvider.notifier).state = _opcionalNovo;
        await tester.pumpAndSettle();

        expect(find.text('Nova versão 0.0.6 disponível'), findsOneWidget);
      },
    );
  });
}
