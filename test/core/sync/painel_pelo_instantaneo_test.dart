import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/domain/models/arranjo_do_painel.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **O painel do gestor não fica no telemóvel dele.**
///
/// Quem troca de aparelho — ou reinstala, que no Punho é coisa segura — tem de
/// encontrar o painel como o deixou. Uma preferência só local dava um painel
/// por telemóvel, e a arrumação que ele fez uma tarde desaparecia na primeira
/// vez que instalasse a app noutro sítio.
///
/// Vai pelo canal do **instantâneo** (`punho_estado_operacional`), com o
/// onboarding e os custos fixos — e não pela fila de operações. A fila serve o
/// que duas pessoas mexem ao mesmo tempo e precisa da ordem do servidor para
/// não se perder; o painel é arrumação de um gestor num sítio só. Pô-lo na
/// fila obrigava a inventar uma entidade nova e a alargar-lhe a lista no
/// servidor, para resolver uma disputa que não existe. Ver `dois_canais_test`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PersistentOperationRepository> repositorio() async {
    SharedPreferences.setMockInitialValues({});
    return PersistentOperationRepository.create();
  }

  final arranjo = ArranjoDoPainel.vazio
      .comEscolha('caixa', escolher: true)
      .comEscolha('entradas-mes', escolher: true);

  test('o painel novo entra no instantâneo que sobe', () async {
    final repo = await repositorio();
    repo.savePainel(arranjo);

    final payload =
        jsonDecode(repo.exportOperationalPayload()) as Map<String, dynamic>;
    expect(payload['painel'], isNotNull);
    expect(
      (payload['painel'] as Map)['escolhidos'],
      containsAll(['caixa', 'entradas-mes']),
    );
  });

  test('marcar um KPI põe o instantâneo por subir', () async {
    final repo = await repositorio();
    expect(repo.hasPendingRemoteChanges, isFalse);

    repo.savePainel(arranjo);

    // Sem isto, a escolha ficava gravada no telemóvel e nunca subia: o painel
    // parecia guardado, e no aparelho seguinte estava vazio.
    expect(repo.hasPendingRemoteChanges, isTrue);
  });

  test('gravar uma máquina não põe o painel a subir', () async {
    // A divisão dos dois canais ao contrário: o trabalho de terreno sobe pela
    // fila, e não pode arrastar o instantâneo atrás dele.
    final repo = await repositorio();
    repo.saveMachine(
      const Machine(
        id: 'm9',
        name: 'Giratória',
        reference: 'GIR-09',
        category: 'Escavação',
        status: MachineStatus.available,
      ),
    );

    expect(repo.hasPendingRemoteChanges, isFalse);
  });

  test('o painel que vem do servidor chega ao aparelho', () async {
    final repo = await repositorio();

    final chegou = repo.importOperationalPayload(
      jsonEncode({
        'onboarding': {'companyName': 'Terraforte', 'legalForm': 'Lda.'},
        'painel': {
          'ordem': ['entradas-mes', 'caixa'],
          'escolhidos': ['entradas-mes', 'caixa'],
        },
      }),
      revision: 4,
    );

    expect(chegou, isTrue);
    expect(repo.painel.noPainel, ['entradas-mes', 'caixa']);
  });

  test('um aparelho com a app antiga não apaga o painel dos outros', () async {
    // O caso que isto trava: o gestor arruma o painel no telemóvel novo, e o
    // aparelho antigo — que ainda não sabe do painel — sincroniza a ficha da
    // empresa. O instantâneo dele não traz a chave `painel`, e ler esse
    // silêncio como "vazio" apagava a arrumação sem erro nenhum à vista.
    final repo = await repositorio();
    repo.savePainel(arranjo);
    // Já subiu: o que se prova aqui é a regra da chave em falta, e não a
    // protecção de quem tem alterações à espera de vez.
    repo.markRemoteSynchronized(8);

    repo.importOperationalPayload(
      jsonEncode({
        'onboarding': {'companyName': 'Terraforte', 'legalForm': 'Lda.'},
      }),
      revision: 9,
    );

    expect(repo.painel, arranjo);
  });

  test('esvaziar o painel de propósito continua a chegar aos outros', () async {
    // A outra metade: a chave vem, com as listas vazias. Aí é escolha dele, e
    // tem de valer.
    final repo = await repositorio();
    repo.savePainel(arranjo);
    repo.markRemoteSynchronized(9);

    repo.importOperationalPayload(
      jsonEncode({
        'onboarding': {'companyName': 'Terraforte', 'legalForm': 'Lda.'},
        'painel': {'ordem': <String>[], 'escolhidos': <String>[]},
      }),
      revision: 10,
    );

    expect(repo.painel, ArranjoDoPainel.vazio);
  });

  group('a janela entre arrumar e sincronizar', () {
    /// O painel de outra pessoa, já no servidor, e uma ficha mais recente.
    String doServidor() => jsonEncode({
      'onboarding': {'companyName': 'Terraforte', 'legalForm': 'Lda.'},
      'painel': {
        'ordem': ['ticket-medio-mes'],
        'escolhidos': ['ticket-medio-mes'],
      },
    });

    test(
      'a arrumação deste aparelho sobrevive ao que chega do servidor',
      () async {
        // O caso concreto: marca-se uma caixa, e antes de haver ciclo de
        // sincronização o outro telemóvel corrige a morada da empresa. A revisão
        // avança, "o servidor manda" — e a arrumação ia-se, calada. Para a ficha
        // da empresa essa regra está certa; para uma preferência que se muda com
        // um toque, a janela é larga de mais.
        final repo = await repositorio();
        repo.savePainel(arranjo);

        repo.importOperationalPayload(doServidor(), revision: 7);

        expect(repo.painel, arranjo, reason: 'a escolha dele ficou de pé');
        // E continua por subir: tem de ir na mesma passagem, senão volta a
        // apanhar a mesma janela no ciclo seguinte.
        expect(repo.hasPendingRemoteChanges, isTrue);
        // A ficha da empresa, essa, cedeu ao servidor como sempre.
        expect(repo.onboarding?.companyName, 'Terraforte');
      },
    );

    test('depois de subir, o painel do servidor volta a mandar', () async {
      final repo = await repositorio();
      repo.savePainel(arranjo);
      repo.markRemoteSynchronized(6);

      repo.importOperationalPayload(doServidor(), revision: 7);

      // Já teve a sua vez. Daqui em diante é o de quem escreveu por último —
      // que é a regra normal de uma preferência partilhada pela empresa.
      expect(repo.painel.noPainel, ['ticket-medio-mes']);
      expect(repo.hasPendingRemoteChanges, isFalse);
    });

    test('arrumar e fechar a app antes de haver rede não perde nada', () async {
      SharedPreferences.setMockInitialValues({});
      final primeiro = await PersistentOperationRepository.create();
      primeiro.savePainel(arranjo);

      // Arranque seguinte, e só aí é que apanha rede.
      final segundo = await PersistentOperationRepository.create();
      segundo.importOperationalPayload(doServidor(), revision: 7);

      expect(segundo.painel, arranjo);
      expect(segundo.hasPendingRemoteChanges, isTrue);
    });
  });

  test('instantâneo antigo, sem painel nenhum, deixa-o vazio', () async {
    // O que está no servidor hoje foi escrito por versões que não sabiam do
    // painel. Lê-se como "ainda não escolheu nada", não como erro.
    final repo = await repositorio();

    final chegou = repo.importOperationalPayload(
      jsonEncode({
        'onboarding': {'companyName': 'Terraforte', 'legalForm': 'Lda.'},
      }),
      revision: 1,
    );

    expect(chegou, isTrue);
    expect(repo.painel, ArranjoDoPainel.vazio);
  });

  test('o painel sobrevive a fechar e abrir a app', () async {
    SharedPreferences.setMockInitialValues({});
    final primeiro = await PersistentOperationRepository.create();
    primeiro.savePainel(arranjo);

    // Mesma gaveta, repositório novo: é o que acontece no arranque seguinte.
    final segundo = await PersistentOperationRepository.create();
    expect(segundo.painel, arranjo);
  });

  test('recomeçar do zero leva o painel com ele', () async {
    final repo = await repositorio();
    repo.savePainel(arranjo);

    repo.resetAll();

    expect(repo.painel, ArranjoDoPainel.vazio);
  });
}
