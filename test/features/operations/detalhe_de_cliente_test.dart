import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/layout/ecra_de_formulario.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/operations/presentation/operational_pages.dart';

import '../dashboard/fixtura.dart';

/// P0: os clientes trazem NIF, email, morada e notas do servidor, mas só
/// apareciam no diálogo de "Novo cliente" — que morria ao fechar. Não havia
/// forma de os voltar a ver. O botão de editar, simétrico ao das máquinas
/// ([MachinesPage]/`_FormularioDeMaquina`), reabre-os.
///
/// Os testes usam um [ProviderContainer] real (sem [ControllerFixo]) e semeiam
/// os clientes através do próprio `addCustomer`, para o repositório e o estado
/// ficarem alinhados — a gravação de uma edição lê o repositório directamente
/// para detectar duplicados.
void main() {
  ProviderContainer containerComClientes(List<Customer> clientes) {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // O repositório de demonstração nasce com um cliente-semente próprio
    // ("Construções Silva", id 'c1') — sem limpar primeiro, os testes viam
    // dois clientes com o mesmo nome e `.first` podia acertar no errado.
    container.read(operationsProvider.notifier).resetAll();
    for (final cliente in clientes) {
      container.read(operationsProvider.notifier).addCustomer(cliente);
    }
    return container;
  }

  const clienteCompleto = Customer(
    id: 'c-silva',
    name: 'Construções Silva',
    phone: '912 111 111',
    taxId: '501234567',
    email: 'geral@silva.pt',
    address: 'Rua Nova 12',
    postalCode: '4700-000',
    locality: 'Braga',
    notes: 'Prefere ser contactado de manhã.',
  );

  testWidgets('a lista de clientes tem um botão de editar, como as máquinas', (
    tester,
  ) async {
    final container = containerComClientes([clienteCompleto]);
    await montarLandscape(
      tester,
      container,
      const ClientsPage(),
      tamanho: const Size(1280, 800),
    );

    // O Tooltip do Material desdobra-se em dois elementos que respondem ao
    // predicado (o mesmo que já obriga o `.last` no teste da máquina); o que
    // interessa aqui é que existe pelo menos um.
    expect(find.byTooltip('Editar cliente'), findsWidgets);
  });

  testWidgets(
    'o botão de editar mostra o NIF, email, morada e notas do cliente',
    (tester) async {
      final container = containerComClientes([clienteCompleto]);
      await montarLandscape(
        tester,
        container,
        const ClientsPage(),
        tamanho: const Size(1280, 800),
      );

      await tester.tap(find.byTooltip('Editar cliente').first);
      await tester.pumpAndSettle();

      expect(find.text('Editar cliente'), findsOneWidget);
      // O nome e o telemóvel também aparecem no cartão por baixo do diálogo
      // (que continua montado): basta confirmar que o campo os traz, sem
      // exigir uma única ocorrência no ecrã todo.
      expect(find.text('Construções Silva'), findsWidgets);
      expect(find.text('912 111 111'), findsWidgets);
      expect(find.text('501234567'), findsOneWidget);
      expect(find.text('geral@silva.pt'), findsOneWidget);
      expect(find.text('Rua Nova 12'), findsOneWidget);
      expect(find.text('4700-000'), findsOneWidget);
      expect(find.text('Braga'), findsOneWidget);
      expect(find.text('Prefere ser contactado de manhã.'), findsOneWidget);
    },
  );

  testWidgets(
    'editar e gravar actualiza o cliente sem perder os outros campos',
    (tester) async {
      final container = containerComClientes([clienteCompleto]);
      await montarLandscape(
        tester,
        container,
        const ClientsPage(),
        tamanho: const Size(1280, 800),
      );

      await tester.tap(find.byTooltip('Editar cliente').first);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Notas'),
        'Já não aceita obras aos sábados.',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(EcraDeFormulario), findsNothing);

      final guardado = container
          .read(operationsProvider)
          .customers
          .firstWhere((c) => c.id == 'c-silva');
      expect(guardado.notes, 'Já não aceita obras aos sábados.');
      // O resto do cliente não se perdeu por causa da edição.
      expect(guardado.taxId, '501234567');
      expect(guardado.email, 'geral@silva.pt');
      expect(guardado.address, 'Rua Nova 12');
    },
  );

  testWidgets(
    'gravar sem mudar o telemóvel ou o NIF não acusa duplicado consigo mesmo',
    (tester) async {
      // Regressão directa do que este P0 introduziu: a validação de
      // duplicados de addCustomer (usada para criar) recusaria sempre a
      // edição, porque o próprio cliente antes de mudar nada bate sempre
      // certo consigo mesmo no telemóvel e no NIF.
      final container = containerComClientes([clienteCompleto]);
      await montarLandscape(
        tester,
        container,
        const ClientsPage(),
        tamanho: const Size(1280, 800),
      );

      await tester.tap(find.byTooltip('Editar cliente').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Já existe um cliente com o mesmo telemóvel ou NIF na empresa.',
        ),
        findsNothing,
      );
      expect(find.byType(EcraDeFormulario), findsNothing);
    },
  );

  testWidgets(
    'editar o telemóvel para o de outro cliente mostra o aviso e não grava',
    (tester) async {
      final outro = clienteCompleto.taxId; // guarda para comparar depois
      final container = containerComClientes([
        clienteCompleto,
        const Customer(
          id: 'c-pereira',
          name: 'João Pereira',
          phone: '912 222 222',
        ),
      ]);
      await montarLandscape(
        tester,
        container,
        const ClientsPage(),
        tamanho: const Size(1280, 800),
      );

      await tester.tap(find.byTooltip('Editar cliente').first);
      await tester.pumpAndSettle();
      expect(find.text('Editar cliente'), findsOneWidget);

      // 'Telemóvel *': o contacto é obrigatório desde 10 de Agosto de 2026 —
      // um cliente sem número não se confirma, não se avisa e não se cobra.
      await tester.enterText(
        find.widgetWithText(TextField, 'Telemóvel *'),
        '912 222 222',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Já existe um cliente com o mesmo telemóvel ou NIF na empresa.',
        ),
        findsOneWidget,
      );
      // Continua aberto: a recusa não fecha o diálogo.
      expect(find.byType(EcraDeFormulario), findsOneWidget);
      final aindaGuardado = container
          .read(operationsProvider)
          .customers
          .firstWhere((c) => c.id == 'c-silva');
      expect(aindaGuardado.phone, '912 111 111');
      expect(aindaGuardado.taxId, outro);
    },
  );
}
