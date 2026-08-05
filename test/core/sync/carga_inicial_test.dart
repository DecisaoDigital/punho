import 'package:flutter_test/flutter_test.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// REGRESSÃO — o que já estava no aparelho nunca subia.
///
/// O registo de operações só dispara em gravações **novas**. Quem já usava a
/// app antes de haver sincronização — ou antes de entrar numa empresa — tinha
/// máquinas e clientes no telemóvel que não iriam subir nunca: não houve
/// gravação nenhuma depois de a fila existir, portanto não havia nada a
/// registar.
///
/// O gestor via os dados no seu aparelho, mais ninguém os via, e **não aparecia
/// erro nenhum**. Foi assim que o telemóvel do Cesar ficou com 7 máquinas e o
/// servidor com zero linhas.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PersistentOperationRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = await PersistentOperationRepository.create();
  });

  Machine maquina(String id) => Machine(
    id: id,
    name: 'Escavadora $id',
    reference: 'REF-$id',
    category: 'terraplanagem',
    status: MachineStatus.available,
  );

  Customer cliente(String id) =>
      Customer(id: id, name: 'Cliente $id', phone: '912345678');

  test('a carga inicial põe na fila o que já lá estava', () async {
    // Simula o estado de quem já usava a app: dados gravados sem ninguém a
    // ouvir (é o que acontece antes de a sincronização arrancar).
    repo.saveMachine(maquina('m1'));
    repo.saveMachine(maquina('m2'));
    repo.saveCustomer(cliente('c1'));

    // Só AGORA alguém começa a ouvir — como no arranque real.
    final registadas = <String>[];
    repo.aoRegistarOperacao = (entidade, id, _) =>
        registadas.add('$entidade:$id');

    // Sem carga inicial, isto fica vazio para sempre.
    final quantas = repo.carregarTudoParaFila();

    expect(quantas, 3);
    expect(
      registadas,
      containsAll(['machine:m1', 'machine:m2', 'customer:c1']),
    );
  });

  test('sem carga inicial, o que já existia não é registado', () async {
    // O comportamento antigo, deixado à vista para se perceber o defeito.
    repo.saveMachine(maquina('m1'));

    final registadas = <String>[];
    repo.aoRegistarOperacao = (entidade, id, _) =>
        registadas.add('$entidade:$id');

    expect(registadas, isEmpty);
  });

  test('gravações posteriores continuam a ser registadas uma a uma', () async {
    final registadas = <String>[];
    repo.aoRegistarOperacao = (entidade, id, _) =>
        registadas.add('$entidade:$id');

    repo.saveMachine(maquina('m9'));

    expect(registadas, ['machine:m9']);
  });

  test('a carga inclui todas as famílias de entidade', () async {
    repo.saveMachine(maquina('m1'));
    repo.saveCustomer(cliente('c1'));
    repo.saveLead(
      Lead(
        id: 'l1',
        name: 'Obra nova',
        phone: '911111111',
        status: LeadStatus.values.first,
        createdAt: DateTime(2026, 8, 2),
      ),
    );

    final entidades = <String>{};
    repo.aoRegistarOperacao = (entidade, _, __) => entidades.add(entidade);
    repo.carregarTudoParaFila();

    expect(entidades, containsAll(['machine', 'customer', 'lead']));
  });

  test('o que chega de outro aparelho não volta a ser enviado', () async {
    // Sem esta guarda, aplicar o que chegou emitia uma operação nova, que
    // voltava a ser enviada, que voltava a chegar — eco sem fim entre dois
    // telemóveis.
    final registadas = <String>[];
    repo.aoRegistarOperacao = (entidade, id, _) =>
        registadas.add('$entidade:$id');

    repo.aplicarOperacaoRemota('machine', {
      'id': 'remota',
      'name': 'Vinda de fora',
      'reference': 'R',
      'category': 'terraplanagem',
      'status': 'available',
    });

    expect(registadas, isEmpty);
    expect(repo.machines.any((m) => m.id == 'remota'), isTrue);
  });
}
