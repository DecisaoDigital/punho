import 'package:flutter_test/flutter_test.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O que a sincronização por operações resolve, e o instantâneo completo não
/// resolvia: duas pessoas a trabalhar ao mesmo tempo sem uma apagar a outra.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PersistentOperationRepository> repositorio() async {
    SharedPreferences.setMockInitialValues({});
    return PersistentOperationRepository.create();
  }

  Machine maquina(String id, String nome, {MachineStatus? estado}) => Machine(
    id: id,
    name: nome,
    reference: id.toUpperCase(),
    category: 'Escavação',
    status: estado ?? MachineStatus.available,
  );

  test('cada alteração local emite uma operação', () async {
    final repo = await repositorio();
    final emitidas = <String>[];
    repo.aoRegistarOperacao = (entidade, id, _) =>
        emitidas.add('$entidade/$id');

    repo.saveMachine(maquina('m1', 'Mini escavadora'));
    repo.saveCustomer(
      const Customer(id: 'c1', name: 'Silva', phone: '910000000'),
    );

    expect(emitidas, ['machine/m1', 'customer/c1']);
  });

  test('aplicar o que veio de fora não emite operação nova', () async {
    // Sem isto, aplicar o que chegou gerava uma operação que voltava a ser
    // enviada, que voltava a chegar — um eco sem fim entre dois telemóveis.
    final repo = await repositorio();
    var emitidas = 0;
    repo.aoRegistarOperacao = (_, __, ___) => emitidas++;

    repo.aplicarOperacaoRemota('machine', {
      'id': 'm9',
      'name': 'Giratória',
      'reference': 'GR-09',
      'category': 'Escavação',
      'status': 'available',
    });

    expect(emitidas, 0);
    expect(repo.machines.single.name, 'Giratória');
  });

  test('dois dispositivos em máquinas diferentes não se pisam', () async {
    // É este o caso que o instantâneo completo perdia: o gestor gravava, o
    // colaborador gravava, e um dos dois ficava sem o trabalho.
    final gestor = await repositorio();
    gestor.saveMachine(maquina('m1', 'Mini escavadora'));

    // Chega a alteração feita pelo colaborador noutra máquina.
    gestor.aplicarOperacaoRemota('machine', {
      'id': 'm2',
      'name': 'Plataforma',
      'reference': 'PE-02',
      'category': 'Elevação',
      'status': 'rented',
    });

    expect(gestor.machines.map((m) => m.id), containsAll(['m1', 'm2']));
    expect(gestor.machines.length, 2);
  });

  test('na mesma máquina, ganha quem chega depois', () async {
    // Ordem dada pelo servidor (`seq`), não pelos relógios dos telemóveis.
    final repo = await repositorio();
    repo.saveMachine(maquina('m1', 'Nome antigo'));

    repo.aplicarOperacaoRemota('machine', {
      'id': 'm1',
      'name': 'Nome novo',
      'reference': 'M1',
      'category': 'Escavação',
      'status': 'maintenance',
    });

    expect(repo.machines.single.name, 'Nome novo');
    expect(repo.machines.single.status, MachineStatus.maintenance);
  });

  test('arquivar viaja como qualquer outra alteração', () async {
    final repo = await repositorio();
    repo.saveMachine(maquina('m1', 'Mini escavadora'));
    final emitidas = <Map<String, Object?>>[];
    repo.aoRegistarOperacao = (_, __, payload) => emitidas.add(payload);

    repo.archiveMachine('m1');

    expect(emitidas, hasLength(1));
    expect(emitidas.single['archived'], isTrue);
  });

  test('entidade desconhecida é ignorada em vez de rebentar', () async {
    // Uma app antiga não pode estoirar porque o servidor aprendeu algo novo.
    final repo = await repositorio();

    repo.aplicarOperacaoRemota('coisa_do_futuro', {'id': 'x'});

    expect(repo.machines, isEmpty);
  });

  test('o que chega fica gravado no telemóvel', () async {
    // Recebido e não persistido perdia-se ao fechar a app, e voltava a ser
    // puxado — ou não, se o cursor já tivesse avançado.
    final repo = await repositorio();
    repo.aplicarOperacaoRemota('customer', {
      'id': 'c9',
      'name': 'Costa',
      'phone': '911111111',
    });

    final outro = await PersistentOperationRepository.create();

    expect(outro.customers.single.name, 'Costa');
  });
}
