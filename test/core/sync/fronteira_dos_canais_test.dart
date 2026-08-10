import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/domain/models/finance.dart';
import 'package:punho/domain/models/historical_month.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/domain/models/workforce.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **A fronteira dos canais.** Este ficheiro é o arame farpado.
///
/// A app sincroniza por três canais e cada coisa tem um dono:
///
/// | Canal | O quê | Quem ganha |
/// |---|---|---|
/// | operações (`punho_operacoes`) | máquinas, clientes, leads, reservas, despesas, recebimentos, colaboradores, veículos | a ordem do servidor (`seq`) |
/// | ficha da empresa (`punho_estado_operacional`) | onboarding, custos fixos, histórico mensal | o servidor: revisão diferente, o local cede |
/// | painel (`punho_painel`) | o arranjo do painel do gestor | o carimbo mais recente de quem arrumou |
///
/// O canal da ficha **não opina sobre entidades**. Nem as sobe, nem as traz.
/// Enquanto opinou, mandava nelas com dados velhos: a 4 de Agosto de 2026, num
/// Redmi, fechar um trabalho gravava, subia à fila de operações, chegava ao
/// servidor — e segundos depois estava outra vez "em curso", porque a ficha
/// tinha escrito por cima com um instantâneo da revisão 1. Sem erro nenhum: a
/// app dizia uma coisa, o servidor dizia outra, e quem trabalhava perdia o
/// trabalho em silêncio.
///
/// **Se um destes testes falhar, a correcção não é mudar o teste.** Uma coisa
/// nova que duas pessoas possam mexer ao mesmo tempo pertence ao registo de
/// operações, que tem ordem do servidor e resolve empates. A ficha da empresa
/// só leva o que um gestor edita sozinho, num sítio só, raramente. Alargar esta
/// lista é reabrir a avaria de 4 de Agosto por outra porta.
///
/// O que este ficheiro **não** cobre, por estar coberto ao lado: quem ganha
/// entre revisões (`o_servidor_manda_test.dart`), o painel fora do instantâneo
/// (`canal_do_painel_test.dart`), e a leitura do disco por inteiro
/// (`dois_canais_test.dart`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// As duas únicas chaves que sobem pelo canal da ficha. A lista vive aqui,
  /// não no código de produção: é a promessa escrita no doc-comment de
  /// `_payloadDaFicha`, e um teste que fosse buscar a lista ao próprio método
  /// nunca falharia — concordaria sempre com o que lá estivesse.
  const oQueAFichaLeva = {'onboarding', 'historicalMonths'};

  /// O que **não** vai pela ficha: as oito listas do canal das operações.
  const asOitoEntidades = [
    'machines',
    'customers',
    'leads',
    'bookings',
    'expenses',
    'receipts',
    'collaborators',
    'vehicles',
  ];

  Future<PersistentOperationRepository> repositorio() async {
    SharedPreferences.setMockInitialValues({});
    return PersistentOperationRepository.create();
  }

  const onboardingLocal = OnboardingData(
    companyName: 'Terraforte',
    legalForm: 'Lda.',
    hasFleet: true,
    collaborators: 4,
    totalMachinesDeclared: 6,
    insertMachinesNow: false,
  );

  /// Uma de cada uma das oito, com uma marca no meio (`FRONTEIRA`) que se pode
  /// procurar no texto do payload. Se alguma voltar a viajar na ficha, a marca
  /// aparece lá.
  void encherDeEntidades(PersistentOperationRepository repo) {
    repo.saveMachine(
      const Machine(
        id: 'maq-FRONTEIRA',
        name: 'Giratória',
        reference: 'GIR-09',
        category: 'Escavação',
        status: MachineStatus.available,
      ),
    );
    repo.saveCustomer(
      const Customer(
        id: 'cli-FRONTEIRA',
        name: 'Construções Silva',
        phone: '912000000',
      ),
    );
    repo.saveLead(
      Lead(
        id: 'lead-FRONTEIRA',
        name: 'Obras do Norte',
        phone: '913000000',
        status: LeadStatus.contacted,
        createdAt: DateTime(2026, 8, 1),
      ),
    );
    repo.saveBooking(
      Booking(
        id: 'res-FRONTEIRA',
        customerId: 'cli-FRONTEIRA',
        machineIds: const ['maq-FRONTEIRA'],
        startsAt: DateTime(2026, 7, 30, 8),
        endsAt: DateTime(2026, 8, 3, 18),
        status: BookingStatus.completed,
        expectedValueCents: 36000,
      ),
    );
    repo.saveExpense(
      Expense(
        id: 'desp-FRONTEIRA',
        date: DateTime(2026, 8, 2),
        amountCents: 4500,
        category: ExpenseCategory.fuel,
        status: ExpensePaymentStatus.paid,
      ),
    );
    repo.saveReceipt(
      Receipt(
        id: 'receb-FRONTEIRA',
        date: DateTime(2026, 8, 3),
        amountCents: 36000,
        customerId: 'cli-FRONTEIRA',
        method: PaymentMethod.transfer,
      ),
    );
    repo.saveCollaborator(
      const Collaborator(
        id: 'colab-FRONTEIRA',
        name: 'Rui Martins',
        status: CollaboratorStatus.active,
      ),
    );
    repo.saveVehicle(
      const Vehicle(
        id: 'veic-FRONTEIRA',
        plate: 'AA-00-BB',
        type: 'Carrinha',
        status: VehicleStatus.active,
      ),
    );
  }

  /// Uma ficha do servidor que traz **tudo**: a dela, e ainda as oito listas com
  /// conteúdo que contradiz o que está no aparelho.
  ///
  /// É de propósito que este payload é válido e completo — o corte tem de estar
  /// na decisão de não o ler, não num erro de leitura pelo caminho.
  String fichaComEntidadesContraditorias() => jsonEncode({
    'onboarding': {
      'companyName': 'Terraforte Unipessoal',
      'legalForm': 'Unipessoal Lda.',
      'hasFleet': true,
      'collaborators': 9,
      'totalMachinesDeclared': 6,
    },
    'historicalMonths': [
      {'year': 2026, 'month': 3, 'revenueReceivedCents': 150000},
    ],
    // A partir daqui é tudo do outro canal. Nada disto pode chegar.
    'machines': [
      {
        'id': 'maq-FRONTEIRA',
        'name': 'Giratória',
        'reference': 'INTRUSA-01',
        'category': 'Escavação',
        'status': 'rented',
      },
    ],
    'customers': [
      {'id': 'cli-FRONTEIRA', 'name': 'INTRUSA', 'phone': '000000000'},
    ],
    'leads': [
      {
        'id': 'lead-INTRUSA',
        'name': 'INTRUSA',
        'phone': '000000000',
        'status': 'newLead',
        'createdAt': '2026-01-01T00:00:00.000',
      },
    ],
    'bookings': [
      {
        'id': 'res-FRONTEIRA',
        'customerId': 'cli-FRONTEIRA',
        'machineIds': ['maq-FRONTEIRA'],
        'startsAt': '2026-07-30T08:00:00.000',
        'endsAt': '2026-08-03T18:00:00.000',
        'status': 'rented',
      },
    ],
    'expenses': const <Object>[],
    'receipts': const <Object>[],
    'collaborators': const <Object>[],
    'vehicles': const <Object>[],
  });

  group('o que sobe pelo instantâneo', () {
    test('a ficha da empresa leva duas chaves, e são estas', () async {
      final repo = await repositorio();
      repo.saveOnboarding(onboardingLocal);

      final ficha =
          jsonDecode(repo.exportarFichaDaEmpresa()) as Map<String, dynamic>;

      expect(
        ficha.keys.toSet(),
        oQueAFichaLeva,
        reason:
            'Apareceu uma chave nova no que sobe pelo instantâneo. Se for uma '
            'coisa que duas pessoas possam mexer ao mesmo tempo, o sítio dela é '
            'o registo de operações — ver o doc-comment de `_payloadDaFicha` em '
            'operation_repository.dart.',
      );
    });

    test('um telemóvel cheio de entidades sobe a mesma ficha', () async {
      final repo = await repositorio();
      repo.saveOnboarding(onboardingLocal);
      repo.saveHistoricalMonth(
        const HistoricalMonth(year: 2026, month: 3, revenueReceivedCents: 1500),
      );
      encherDeEntidades(repo);

      final texto = repo.exportarFichaDaEmpresa();

      // Nem por chave, nem enfiadas noutro sítio: a marca não aparece em lado
      // nenhum do payload.
      expect(
        texto,
        isNot(contains('FRONTEIRA')),
        reason:
            'Uma entidade voltou a viajar na ficha da empresa. Era assim que o '
            'gestor, ao gravar os custos fixos com a cópia local atrasada, '
            'fazia uma reserva entregue voltar a alugada.',
      );
      final ficha = jsonDecode(texto) as Map<String, dynamic>;
      expect(ficha.keys.toSet(), oQueAFichaLeva);
      for (final entidade in asOitoEntidades) {
        expect(ficha.containsKey(entidade), isFalse, reason: entidade);
      }

      // E o que é dele continua a subir — senão isto passava por não enviar
      // nada, que é uma avaria pior.
      expect(
        (ficha['onboarding'] as Map)['companyName'],
        'Terraforte',
      );
      expect((ficha['historicalMonths'] as List).single, isA<Map>());
    });
  });

  group('o que a ficha traz não substitui entidades', () {
    test('nenhuma das oito listas cede à ficha do servidor', () async {
      final repo = await repositorio();
      encherDeEntidades(repo);

      expect(
        repo.importarFichaDaEmpresa(
          fichaComEntidadesContraditorias(),
          revision: 7,
        ),
        isTrue,
      );

      // As oito, uma a uma. O que está no aparelho é o que veio pela fila de
      // operações, e é ele que fica.
      expect(repo.machines.single.reference, 'GIR-09');
      expect(repo.machines.single.status, MachineStatus.available);
      expect(repo.customers.single.name, 'Construções Silva');
      expect(repo.leads.single.id, 'lead-FRONTEIRA');
      expect(repo.bookings.single.status, BookingStatus.completed);
      expect(repo.expenses.single.id, 'desp-FRONTEIRA');
      expect(repo.receipts.single.amountCents, 36000);
      expect(repo.collaborators.single.name, 'Rui Martins');
      expect(repo.vehicles.single.plate, 'AA-00-BB');

      // E o que é dela chegou — a fronteira não é uma porta fechada, é uma
      // porta com dono.
      expect(repo.onboarding?.companyName, 'Terraforte Unipessoal');
      expect(repo.historicalMonths.single.revenueReceivedCents, 150000);
      expect(repo.remoteRevision, 7);
    });

    test('o gestor grava os custos fixos, o operador não perde nada', () async {
      // A cena de 4 de Agosto, do lado das finanças. O operador entregou a
      // máquina e registou o pagamento; o gestor, noutro telemóvel, gravou os
      // custos fixos. A ficha que desce a este aparelho é anterior a tudo isso.
      final repo = await repositorio();
      encherDeEntidades(repo);

      repo.importarFichaDaEmpresa(
        fichaComEntidadesContraditorias(),
        revision: 12,
      );

      expect(repo.receipts.single.id, 'receb-FRONTEIRA');
      expect(repo.machines.single.status, MachineStatus.available);
      expect(repo.bookings.single.status, BookingStatus.completed);
    });
  });

  group('a ficha não escreve no canal das operações', () {
    test('gravar a ficha da empresa não regista operação nenhuma', () async {
      final repo = await repositorio();
      final registadas = <String>[];
      repo.aoRegistarOperacao = (entidade, id, _) =>
          registadas.add('$entidade/$id');

      repo.saveOnboarding(onboardingLocal);
      repo.saveHistoricalMonth(
        const HistoricalMonth(year: 2026, month: 3, revenueReceivedCents: 1500),
      );

      // A ficha sobe pelo instantâneo, com a revisão dela. Enfileirar isto como
      // operação era pô-la a subir por dois canais ao mesmo tempo, cada um com
      // a sua regra de quem ganha.
      expect(registadas, isEmpty);
    });

    test('importar a ficha do servidor também não', () async {
      final repo = await repositorio();
      encherDeEntidades(repo);
      final registadas = <String>[];
      repo.aoRegistarOperacao = (entidade, id, _) =>
          registadas.add('$entidade/$id');

      repo.importarFichaDaEmpresa(
        fichaComEntidadesContraditorias(),
        revision: 7,
      );

      // O que desce por um canal não pode voltar a subir pelo outro: seria um
      // eco entre os dois, e o registo de operações passaria a ter linhas que
      // ninguém escreveu.
      expect(registadas, isEmpty);
    });

    test('e ao contrário: gravar uma máquina regista, sim', () async {
      // Sem isto, os dois testes acima passavam com o `aoRegistarOperacao`
      // partido — e uma sonda que nunca dispara não prova nada.
      final repo = await repositorio();
      final registadas = <String>[];
      repo.aoRegistarOperacao = (entidade, id, _) =>
          registadas.add('$entidade/$id');

      encherDeEntidades(repo);

      expect(registadas, contains('machine/maq-FRONTEIRA'));
      expect(registadas, hasLength(asOitoEntidades.length));
    });
  });
}
