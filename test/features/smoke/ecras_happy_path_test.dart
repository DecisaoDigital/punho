import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/finance.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/dashboard/presentation/dashboard_page.dart';
import 'package:punho/features/finance/presentation/finance_pages.dart';
import 'package:punho/features/operations/presentation/operational_pages.dart';

/// Fase 4 da estabilização: cada ecrã do happy path é montado ao menos uma vez,
/// em estado vazio e em estado povoado, e não pode lançar nada.
///
/// Não substitui o smoke manual — não clica em tudo — mas apanha o caso em que
/// um ecrã deixa de abrir de todo, que é o que não pode acontecer à frente de
/// um cliente.
/// Os dois tamanhos reais em que o Punho corre. O 800x600 por omissão do
/// flutter_test não é nenhum deles e dava falsos positivos de overflow.
const _tamanhos = <String, Size>{
  'telemóvel 411x900': Size(411, 900),
  'Windows 1280x800': Size(1280, 800),
};

void main() {
  void ecraDe(WidgetTester tester, Size tamanho) {
    tester.view.physicalSize = tamanho;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Scaffold à volta de propósito: as páginas de operação (Clientes,
  /// Máquinas, Marcações) devolvem um SafeArea e contam com o Scaffold da
  /// AppShell para terem um Material ascendente. Montá-las a seco fazia
  /// rebentar os ChoiceChip com "No Material widget found" — artefacto do
  /// teste, não da app.
  Future<void> montar(WidgetTester tester, Widget ecra) async {
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(home: Scaffold(body: ecra))),
    );
    await tester.pumpAndSettle();
  }

  /// Povoa o estado como um dia real de trabalho: cliente novo, reserva
  /// confirmada, um recebimento e uma despesa.
  ProviderContainer povoado() {
    final c = ProviderContainer();
    final controller = c.read(operationsProvider.notifier);
    controller.addCustomer(
      const Customer(id: 'c-novo', name: 'Obras do Norte', phone: '933 333 333'),
    );
    controller.addBooking(
      Booking(
        id: 'b-smoke',
        customerId: 'c-novo',
        machineIds: const ['m1'],
        startsAt: DateTime.now().add(const Duration(days: 2)),
        endsAt: DateTime.now().add(const Duration(days: 4)),
        status: BookingStatus.confirmed,
      ),
    );
    controller.saveReceipt(
      Receipt(
        id: 'r-smoke',
        date: DateTime.now(),
        amountCents: 25000,
        customerId: 'c-novo',
        method: PaymentMethod.transfer,
      ),
    );
    controller.saveExpense(
      Expense(
        id: 'e-smoke',
        date: DateTime.now(),
        amountCents: 4500,
        category: ExpenseCategory.other,
        status: ExpensePaymentStatus.paid,
      ),
    );
    return c;
  }

  Future<void> montarEm(
    WidgetTester tester,
    ProviderContainer container,
    Widget ecra,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: ecra)),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Estado vazio (empresa acabada de criar)', () {
    final ecras = <String, Widget>{
      'Onboarding': const OnboardingPage(),
      'Clientes': const ClientsPage(),
      'Máquinas': const MachinesPage(),
      'Marcações': const BookingsPage(),
      'Dados iniciais': const InitialDataTasksPage(),
      'Histórico mensal': const HistoricalDataPage(),
      'Recebimentos': const FinanceListPage(
        title: 'Recebimentos',
        expenses: false,
      ),
      'Despesas': const FinanceListPage(title: 'Despesas', expenses: true),
      'Registar recebimento': const RegisterReceiptPage(),
      'Registar despesa': const RegisterExpensePage(),
      'Painel': const DashboardPage(),
    };

    ecras.forEach((nome, ecra) {
      _tamanhos.forEach((rotulo, tamanho) {
        testWidgets('$nome abre sem lançar · $rotulo', (tester) async {
          ecraDe(tester, tamanho);
          await montar(tester, ecra);
          expect(tester.takeException(), isNull);
        });
      });
    });
  });

  group('Estado povoado (cliente, reserva, recebimento, despesa)', () {
    final ecras = <String, Widget>{
      'Clientes': const ClientsPage(),
      'Máquinas': const MachinesPage(),
      'Marcações': const BookingsPage(),
      'Recebimentos': const FinanceListPage(
        title: 'Recebimentos',
        expenses: false,
      ),
      'Despesas': const FinanceListPage(title: 'Despesas', expenses: true),
      'Painel': const DashboardPage(),
    };

    ecras.forEach((nome, ecra) {
      _tamanhos.forEach((rotulo, tamanho) {
        testWidgets('$nome abre sem lançar · $rotulo', (tester) async {
          ecraDe(tester, tamanho);
          final c = povoado();
          addTearDown(c.dispose);
          await montarEm(tester, c, ecra);
          expect(tester.takeException(), isNull);
        });
      });
    });

    testWidgets('o recebimento registado aparece na lista', (tester) async {
      ecraDe(tester, const Size(411, 900));
      final c = povoado();
      addTearDown(c.dispose);
      await montarEm(
        tester,
        c,
        const FinanceListPage(title: 'Recebimentos', expenses: false),
      );

      expect(find.text('250,00 €'), findsWidgets);
      expect(find.text('Este mês: 250,00 €'), findsOneWidget);
    });

    testWidgets('o cliente criado aparece na lista de clientes', (tester) async {
      ecraDe(tester, const Size(411, 900));
      final c = povoado();
      addTearDown(c.dispose);
      await montarEm(tester, c, const ClientsPage());
      expect(find.text('Obras do Norte'), findsOneWidget);
    });
  });

  group('Regras de negócio no ecrã de clientes', () {
    test('cliente duplicado por telemóvel é recusado', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final controller = c.read(operationsProvider.notifier);
      controller.addCustomer(
        const Customer(id: 'c-a', name: 'Um', phone: '944 444 444'),
      );
      expect(
        () => controller.addCustomer(
          const Customer(id: 'c-b', name: 'Outro', phone: '944 444 444'),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('cliente duplicado por NIF é recusado', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final controller = c.read(operationsProvider.notifier);
      controller.addCustomer(
        const Customer(
          id: 'c-a',
          name: 'Um',
          phone: '955 000 000',
          taxId: '501234567',
        ),
      );
      expect(
        () => controller.addCustomer(
          const Customer(
            id: 'c-b',
            name: 'Outro',
            phone: '955 111 111',
            taxId: '501234567',
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Reservas', () {
    test('reserva sem sobreposição é aceite e a sobreposta é recusada', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final controller = c.read(operationsProvider.notifier);
      expect(
        controller.addBooking(
          Booking(
            id: 'b1',
            customerId: 'c1',
            machineIds: const ['m1'],
            startsAt: DateTime(2027, 3, 1),
            endsAt: DateTime(2027, 3, 5),
            status: BookingStatus.confirmed,
          ),
        ),
        isNull,
      );
      final conflito = controller.addBooking(
        Booking(
          id: 'b2',
          customerId: 'c1',
          machineIds: const ['m1'],
          startsAt: DateTime(2027, 3, 4),
          endsAt: DateTime(2027, 3, 8),
          status: BookingStatus.confirmed,
        ),
      );
      expect(conflito, isNotNull);
      expect(conflito!.booking.id, 'b1');
      expect(c.read(operationsProvider).bookings.any((b) => b.id == 'b2'), isFalse);
    });

    test('máquina diferente no mesmo período não conflitua', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final controller = c.read(operationsProvider.notifier);
      // m2 vem parada no arranque de demonstração; para poder ser reservada
      // tem primeiro de ser posta em serviço.
      controller.updateMachineStatus('m2', MachineStatus.available);
      controller.addBooking(
        Booking(
          id: 'b1',
          customerId: 'c1',
          machineIds: const ['m1'],
          startsAt: DateTime(2027, 4, 1),
          endsAt: DateTime(2027, 4, 5),
          status: BookingStatus.confirmed,
        ),
      );
      expect(
        controller.addBooking(
          Booking(
            id: 'b2',
            customerId: 'c1',
            machineIds: const ['m2'],
            startsAt: DateTime(2027, 4, 1),
            endsAt: DateTime(2027, 4, 5),
            status: BookingStatus.confirmed,
          ),
        ),
        isNull,
      );
    });
  });
}
