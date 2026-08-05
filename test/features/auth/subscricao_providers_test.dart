import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/features/auth/subscricao_providers.dart';

/// `limiteColaboradoresEfetivoProvider` combina o limite do servidor com o
/// local. `limiteColaboradoresServidorProvider` é substituído directamente
/// (não através de `subscricaoServiceProvider`/`estadoAcessoProvider`) porque
/// o primeiro está protegido por `SupabaseConfig.enabled`, que é sempre
/// `false` nos testes (sem `--dart-define`) — o mesmo motivo por que
/// `motorSyncProvider`, em `features/sync/sync_providers.dart`, não tem
/// testes directos: o portão é uma linha só, e o que interessa testar é o que
/// vem depois dele.
void main() {
  test('o limite do servidor vale sobre o valor local do onboarding', () async {
    final c = ProviderContainer(
      overrides: [
        limiteColaboradoresServidorProvider.overrideWith((ref) async => 10),
      ],
    );
    addTearDown(c.dispose);

    // O local (onboarding) fica no valor de omissão (3) — não foi tocado.
    expect(c.read(operationsProvider).activeCollaboratorLimit, 3);

    await c.read(limiteColaboradoresServidorProvider.future);
    expect(c.read(limiteColaboradoresEfetivoProvider), 10);
  });

  test('leitura falhada (ou sem servidor) cai no valor local', () async {
    final c = ProviderContainer(
      overrides: [
        // `null` é como o serviço e o gate reportam "não foi possível saber"
        // — falha de rede, modo demonstração, sem sessão, sem empresa.
        limiteColaboradoresServidorProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(c.dispose);

    await c.read(limiteColaboradoresServidorProvider.future);
    expect(
      c.read(limiteColaboradoresEfetivoProvider),
      c.read(operationsProvider).activeCollaboratorLimit,
    );
  });

  test('enquanto o servidor ainda não respondeu, o efetivo é já o local — não '
      'fica bloqueado à espera', () {
    final c = ProviderContainer(
      overrides: [
        limiteColaboradoresServidorProvider.overrideWith(
          (ref) => Future<int?>.delayed(const Duration(seconds: 5), () => 1),
        ),
      ],
    );
    addTearDown(c.dispose);

    // Sem `await`: lido logo a seguir a criar o container.
    expect(
      c.read(limiteColaboradoresEfetivoProvider),
      c.read(operationsProvider).activeCollaboratorLimit,
    );
  });
}
