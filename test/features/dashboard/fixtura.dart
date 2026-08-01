import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/core/theme/punho_theme.dart';
import 'package:punho/features/auth/acesso_providers.dart';
import 'package:punho/features/auth/data/acesso_service.dart';
import 'package:punho/domain/models/finance.dart';
import 'package:punho/domain/models/operations.dart';
// O modelo tem o seu próprio TimeOfDay (sem depender do Flutter); com prefixo
// para não colidir com o do Material.
import 'package:punho/domain/models/workforce.dart' as pw;
import 'package:punho/domain/models/workforce.dart'
    show
        Collaborator,
        CollaboratorStatus,
        InsuranceFrequency,
        Vehicle,
        VehicleStatus,
        WorkDay;

/// Data fixa de todos os testes do painel. Sem isto os KPIs mudavam de valor
/// com o dia em que a suite corre.
final agoraFixa = DateTime(2026, 7, 15, 10, 30);

/// Empresa com movimento: dá números a todos os cinco slides.
OperationsState estadoComMovimento() => OperationsState(
  onboarded: true,
  ownerName: 'Alfredo',
  companyName: 'Alugueres Norte',
  legalForm: 'Lda.',
  hasFleet: true,
  declaredCollaboratorCount: 2,
  declaredVehicleCount: 1,
  totalMachinesDeclared: 3,
  companyTaxId: '501234567',
  companyPhone: '912 000 000',
  companyEmail: 'geral@exemplo.pt',
  companyAddress: 'Rua das Máquinas 10',
  companyPostalCode: '4700-000',
  companyLocality: 'Braga',
  revenueLastYearCents: 12000000,
  revenueThisYearCents: 4000000,
  maintenanceLastYearCents: 500000,
  fixedMonthlyCostsCents: 300000,
  machines: const [
    Machine(
      id: 'm1',
      name: 'Mini escavadora',
      reference: 'ME-01',
      category: 'Escavação',
      status: MachineStatus.rented,
      dailyRateCents: 18500,
    ),
    Machine(
      id: 'm2',
      name: 'Plataforma elevatória',
      reference: 'PE-02',
      category: 'Elevação',
      status: MachineStatus.available,
    ),
    Machine(
      id: 'm3',
      name: 'Martelo demolidor',
      reference: 'MD-03',
      category: 'Demolição',
      // O estado Parada saiu na v0.0.5: uma máquina sem aluguer está
      // disponível. Continua a ser a que nunca foi alugada.
      status: MachineStatus.available,
    ),
  ],
  customers: const [
    Customer(id: 'c1', name: 'Construções Silva', phone: '912 111 111'),
    Customer(id: 'c2', name: 'João Pereira', phone: '912 222 222'),
  ],
  leads: [
    Lead(
      id: 'l1',
      name: 'Obra do Porto',
      phone: '913 000 001',
      status: LeadStatus.newLead,
      createdAt: agoraFixa.subtract(const Duration(days: 4)),
    ),
    Lead(
      id: 'l2',
      name: 'Quinta de Braga',
      phone: '913 000 002',
      status: LeadStatus.newLead,
      createdAt: agoraFixa.subtract(const Duration(days: 1)),
    ),
    Lead(
      id: 'l3',
      name: 'Vila Verde',
      phone: '913 000 003',
      status: LeadStatus.converted,
      createdAt: agoraFixa.subtract(const Duration(days: 10)),
    ),
    Lead(
      id: 'l4',
      name: 'Perdida',
      phone: '913 000 004',
      status: LeadStatus.lost,
      createdAt: agoraFixa.subtract(const Duration(days: 12)),
    ),
  ],
  bookings: [
    // Confirmada dentro de 3 dias — entra no mini-calendário.
    Booking(
      id: 'b-futura',
      customerId: 'c1',
      customerNameSnapshot: 'Construções Silva',
      machineIds: const ['m1'],
      startsAt: agoraFixa.add(const Duration(days: 3)),
      endsAt: agoraFixa.add(const Duration(days: 6)),
      status: BookingStatus.confirmed,
      expectedValueCents: 120000,
    ),
    // Terminou há 20 dias e ainda tem dinheiro por receber: cobrança em atraso.
    Booking(
      id: 'b-atraso',
      customerId: 'c2',
      customerNameSnapshot: 'João Pereira',
      machineIds: const ['m2'],
      startsAt: agoraFixa.subtract(const Duration(days: 24)),
      endsAt: agoraFixa.subtract(const Duration(days: 20)),
      status: BookingStatus.completed,
      expectedValueCents: 78000,
    ),
    // Concluída e paga, na semana passada.
    Booking(
      id: 'b-paga',
      customerId: 'c1',
      customerNameSnapshot: 'Construções Silva',
      machineIds: const ['m1'],
      startsAt: agoraFixa.subtract(const Duration(days: 9)),
      endsAt: agoraFixa.subtract(const Duration(days: 7)),
      status: BookingStatus.completed,
      expectedValueCents: 90000,
    ),
  ],
  receipts: [
    Receipt(
      id: 'r1',
      date: agoraFixa.subtract(const Duration(days: 7)),
      amountCents: 90000,
      customerId: 'c1',
      bookingId: 'b-paga',
      method: PaymentMethod.transfer,
    ),
    Receipt(
      id: 'r2',
      date: agoraFixa.subtract(const Duration(days: 2)),
      amountCents: 42000,
      customerId: 'c1',
      method: PaymentMethod.mbWay,
    ),
    // Junho, para haver termo de comparação.
    Receipt(
      id: 'r3',
      date: DateTime(2026, 6, 20),
      amountCents: 110000,
      customerId: 'c2',
      method: PaymentMethod.cash,
    ),
  ],
  expenses: [
    Expense(
      id: 'e1',
      date: agoraFixa.subtract(const Duration(days: 5)),
      amountCents: 25000,
      category: ExpenseCategory.machineMaintenance,
      status: ExpensePaymentStatus.paid,
    ),
    Expense(
      id: 'e2',
      date: agoraFixa.subtract(const Duration(days: 3)),
      amountCents: 18000,
      category: ExpenseCategory.fuel,
      status: ExpensePaymentStatus.paid,
    ),
    Expense(
      id: 'e3',
      date: agoraFixa.subtract(const Duration(days: 1)),
      amountCents: 30000,
      category: ExpenseCategory.supplies,
      status: ExpensePaymentStatus.unpaid,
    ),
    // Manutenção de meses anteriores, para a média de 6 meses existir.
    Expense(
      id: 'e4',
      date: DateTime(2026, 6, 10),
      amountCents: 40000,
      category: ExpenseCategory.machineMaintenance,
      status: ExpensePaymentStatus.paid,
    ),
    Expense(
      id: 'e5',
      date: DateTime(2026, 5, 10),
      amountCents: 20000,
      category: ExpenseCategory.machineMaintenance,
      status: ExpensePaymentStatus.paid,
    ),
  ],
  collaborators: const [
    Collaborator(
      id: 'col-1',
      name: 'Ana',
      status: CollaboratorStatus.active,
      costCents: 110000,
      schedule: {
        1: WorkDay(
          works: true,
          start: pw.TimeOfDay(9, 0),
          end: pw.TimeOfDay(18, 0),
        ),
        2: WorkDay(
          works: true,
          start: pw.TimeOfDay(9, 0),
          end: pw.TimeOfDay(18, 0),
        ),
      },
    ),
    // Sem custo: gera tarefa "completar ficha".
    Collaborator(id: 'col-2', name: 'Bruno', status: CollaboratorStatus.active),
  ],
  vehicles: const [
    Vehicle(
      id: 'v1',
      plate: 'AA-00-BB',
      type: 'Carrinha',
      status: VehicleStatus.active,
      monthlyPaymentCents: 11000,
      insuranceCents: 108000,
      insuranceFrequency: InsuranceFrequency.annual,
    ),
  ],
);

/// Empresa configurada mas sem um único movimento — o caso dos falsos zeros.
OperationsState estadoSemMovimento() => const OperationsState(
  onboarded: true,
  ownerName: 'Alfredo',
  companyName: 'Alugueres Norte',
  legalForm: 'Lda.',
  hasFleet: false,
  declaredCollaboratorCount: 0,
  totalMachinesDeclared: 0,
);

/// Empresa com um cliente em dívida há 45 dias — o caso vermelho da
/// recomendação do dia.
OperationsState estadoComDividaAntiga() => OperationsState(
  onboarded: true,
  ownerName: 'Alfredo',
  companyName: 'Alugueres Norte',
  legalForm: 'Lda.',
  machines: const [
    Machine(
      id: 'm1',
      name: 'Mini escavadora',
      reference: 'ME-01',
      category: 'Escavação',
      status: MachineStatus.available,
    ),
  ],
  customers: const [
    Customer(id: 'c-devedor', name: 'Manuel Antunes', phone: '912 333 333'),
  ],
  bookings: [
    Booking(
      id: 'b-antiga',
      customerId: 'c-devedor',
      customerNameSnapshot: 'Manuel Antunes',
      machineIds: const ['m1'],
      startsAt: agoraFixa.subtract(const Duration(days: 50)),
      endsAt: agoraFixa.subtract(const Duration(days: 45)),
      status: BookingStatus.completed,
      expectedValueCents: 62000,
    ),
  ],
  receipts: [
    Receipt(
      id: 'r1',
      date: agoraFixa.subtract(const Duration(days: 3)),
      amountCents: 150000,
      customerId: 'c-devedor',
      method: PaymentMethod.transfer,
    ),
  ],
);

/// Empresa em que nenhuma das cinco regras se aplica: sem dívidas, sem custos
/// desproporcionados, sem histórico homólogo e sem conversão notável.
OperationsState estadoSemRecomendacao() => OperationsState(
  onboarded: true,
  ownerName: 'Alfredo',
  companyName: 'Alugueres Norte',
  legalForm: 'Lda.',
  receipts: [
    Receipt(
      id: 'r1',
      date: agoraFixa.subtract(const Duration(days: 2)),
      amountCents: 80000,
      customerId: 'c1',
      method: PaymentMethod.cash,
    ),
  ],
);

/// Empresa a converter 40% das leads e sem problemas de dinheiro — o caso verde
/// da recomendação do dia.
OperationsState estadoComBoaConversao() => OperationsState(
  onboarded: true,
  ownerName: 'Alfredo',
  companyName: 'Alugueres Norte',
  legalForm: 'Lda.',
  receipts: [
    Receipt(
      id: 'r1',
      date: agoraFixa.subtract(const Duration(days: 4)),
      amountCents: 210000,
      customerId: 'c1',
      method: PaymentMethod.transfer,
    ),
  ],
  leads: [
    for (var i = 0; i < 2; i++)
      Lead(
        id: 'convertida-$i',
        name: 'Cliente ${i + 1}',
        phone: '910 000 00$i',
        status: LeadStatus.converted,
        createdAt: agoraFixa.subtract(Duration(days: 6 + i)),
      ),
    for (var i = 0; i < 3; i++)
      Lead(
        id: 'nova-$i',
        name: 'Lead ${i + 1}',
        phone: '911 000 00$i',
        status: LeadStatus.newLead,
        createdAt: agoraFixa.subtract(Duration(days: 2 + i)),
      ),
  ],
);

/// Controller que devolve um estado fixo, sem repositório por trás.
class ControllerFixo extends OperationsController {
  ControllerFixo(this.fixo);
  final OperationsState fixo;

  @override
  OperationsState build() => fixo;
}

ProviderContainer containerCom(
  OperationsState estado, {
  List<Convite>? convites,
}) {
  final container = ProviderContainer(
    overrides: [
      operationsProvider.overrideWith(() => ControllerFixo(estado)),
      // Sem override, o provider dos convites tenta o `Supabase.instance` e fica
      // em erro — que é exactamente o comportamento do modo de demonstração.
      if (convites != null)
        convitesProvider.overrideWith((ref) async => convites),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Monta um widget numa janela landscape de tablet — a forma para que o painel
/// foi desenhado.
Future<void> montarLandscape(
  WidgetTester tester,
  ProviderContainer container,
  Widget child, {
  Size tamanho = const Size(1280, 800),
}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      // O tema real, não um ThemeData qualquer: senão os CTA saíam roxos em vez
      // de laranja e as capturas não valiam para comparar com o mockup.
      child: MaterialApp(
        theme: PunhoTheme.light,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
