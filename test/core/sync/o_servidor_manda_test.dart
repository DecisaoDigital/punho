import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/domain/models/historical_month.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **O servidor manda.**
///
/// Regra da casa para o canal do instantâneo (`punho_estado_operacional`), que
/// carrega a ficha da empresa: onboarding, custos fixos e histórico mensal.
///
/// 1. Um telemóvel que esteve sem rede abre a app e **recebe** o que está no
///    servidor. Não impõe o que sabia quando se desligou.
/// 2. Só as alterações escritas **em cima** desse estado fresco é que sobem — e
///    a partir daí são elas a verdade para todos os outros.
///
/// Antes disto havia uma terceira hipótese: revisões a divergir davam
/// `requiresReview` e a sincronização parava à espera de alguém. Não há
/// ninguém: o aparelho ficava a mostrar uma ficha que já não era a da empresa,
/// sem erro nenhum à vista.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PersistentOperationRepository> repositorio() async {
    SharedPreferences.setMockInitialValues({});
    return PersistentOperationRepository.create();
  }

  String fichaDoServidor(String nome) => jsonEncode({
    'onboarding': {
      'companyName': nome,
      'legalForm': 'Lda.',
      'hasFleet': true,
      'collaborators': 4,
      'totalMachinesDeclared': 6,
    },
    'historicalMonths': const [],
  });

  /// `OnboardingData` não tem `copyWith` — a ficha reescreve-se inteira, que é
  /// como o ecrã de Definições da Empresa a grava.
  OnboardingData fichaCom(OnboardingData base, {required int colaboradores}) =>
      OnboardingData(
        companyName: base.companyName,
        legalForm: base.legalForm,
        hasFleet: base.hasFleet,
        collaborators: colaboradores,
        totalMachinesDeclared: base.totalMachinesDeclared,
        insertMachinesNow: base.insertMachinesNow,
      );

  const maquina = Machine(
    id: 'm9',
    name: 'Giratória',
    reference: 'GIR-09',
    category: 'Escavação',
    status: MachineStatus.available,
  );

  group('o que fica por subir', () {
    test('gravar uma entidade não põe a ficha da empresa por subir', () async {
      final repo = await repositorio();

      repo.saveMachine(maquina);

      // A máquina é do canal das operações e sobe por lá. Marcá-la aqui fazia
      // a revisão do instantâneo avançar por causa dela — e nos outros
      // telemóveis a revisão deixava de bater certo, obrigando-os a deitar
      // fora a ficha que tivessem por subir.
      expect(repo.hasPendingRemoteChanges, isFalse);
    });

    test('gravar a ficha da empresa põe-na por subir', () async {
      final repo = await repositorio();

      repo.saveHistoricalMonth(
        const HistoricalMonth(year: 2026, month: 3, revenueReceivedCents: 1500),
      );

      expect(repo.hasPendingRemoteChanges, isTrue);
    });

    test('e o que se grava fica no aparelho de qualquer maneira', () async {
      // Deixar de marcar por subir não pode significar deixar de gravar: a
      // máquina tem de lá estar no arranque seguinte.
      SharedPreferences.setMockInitialValues({});
      final antes = await PersistentOperationRepository.create();
      antes.saveMachine(maquina);

      final depois = await PersistentOperationRepository.create();

      expect(depois.machines.single.reference, 'GIR-09');
    });
  });

  group('quem ganha', () {
    test('a revisão avança: o aparelho recebe e a ficha local perde', () async {
      final repo = await repositorio();
      repo.importarFichaDaEmpresa(fichaDoServidor('Terraforte'), revision: 3);

      // Uma semana sem rede, e o gestor mexeu na ficha neste telemóvel.
      repo.saveOnboarding(fichaCom(repo.onboarding!, colaboradores: 99));
      expect(repo.hasPendingRemoteChanges, isTrue);

      // Volta a haver rede e o servidor está na revisão 7. É ele que manda.
      repo.importarFichaDaEmpresa(
        fichaDoServidor('Terraforte Unipessoal'),
        revision: 7,
      );

      expect(repo.onboarding?.companyName, 'Terraforte Unipessoal');
      expect(repo.onboarding?.collaborators, 4);
      expect(repo.remoteRevision, 7);
      expect(repo.hasPendingRemoteChanges, isFalse);
    });

    test('a alteração feita já com o estado fresco é que sobe', () async {
      final repo = await repositorio();
      repo.importarFichaDaEmpresa(fichaDoServidor('Terraforte'), revision: 7);
      expect(repo.hasPendingRemoteChanges, isFalse);

      // Agora sim: escrita em cima do que o servidor tem.
      repo.saveOnboarding(fichaCom(repo.onboarding!, colaboradores: 9));

      expect(repo.hasPendingRemoteChanges, isTrue);
      expect(repo.remoteRevision, 7);

      // É este par — "por subir" com a revisão do servidor — que autoriza o
      // envio em `SincronizacaoFichaEmpresa`. Depois de aceite, fica limpo.
      repo.markRemoteSynchronized(8);
      expect(repo.hasPendingRemoteChanges, isFalse);
      expect(repo.onboarding?.collaborators, 9);
    });
  });

  group('no telemóvel do operador não fica nada da empresa', () {
    test('para de gravar e apaga o que já lá estava', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = await PersistentOperationRepository.create();
      repo.saveMachine(maquina);
      repo.saveOnboarding(
        const OnboardingData(
          companyName: 'Terraforte',
          legalForm: 'Lda.',
          hasFleet: true,
          collaborators: 4,
          totalMachinesDeclared: 6,
          insertMachinesNow: false,
        ),
      );

      // É isto que `SincronizacaoFichaEmpresa` chama quando `punho_membros` diz
      // que este utilizador não é gestor.
      repo.naoGuardarNoAparelho();

      // Não basta parar de escrever: o que foi gravado antes tinha de sair.
      final depois = await PersistentOperationRepository.create();
      expect(depois.machines, isEmpty);
      expect(depois.onboarding, isNull);
    });

    test('o que grava a seguir também não fica', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = await PersistentOperationRepository.create();
      repo.naoGuardarNoAparelho();

      repo.saveMachine(maquina);

      // Em memória está — veio do servidor e é o que o ecrã mostra.
      expect(repo.machines.single.reference, 'GIR-09');
      // No aparelho não.
      expect((await PersistentOperationRepository.create()).machines, isEmpty);
    });
  });
}
