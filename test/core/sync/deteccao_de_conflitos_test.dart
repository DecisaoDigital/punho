import 'package:flutter_test/flutter_test.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/domain/models/conflito_pendente.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O caso que isto protege é concreto: dois colaboradores sem rede, cada um a
/// prometer a mesma giratória a um cliente diferente. Quando as duas reservas
/// chegam ao servidor, "quem chega depois fica por cima" resolvia a disputa em
/// silêncio — e alguém ia ao estaleiro buscar uma máquina que já lá não estava.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PersistentOperationRepository repo;
  late List<ConflitoPendente> detectados;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = await PersistentOperationRepository.create();
    detectados = [];
    repo.aoDetectarConflito = detectados.add;
  });

  Map<String, dynamic> reserva({
    required String id,
    required List<String> maquinas,
    required int inicioDia,
    required int fimDia,
    String estado = 'confirmed',
    String? responsavel,
  }) => {
    'id': id,
    'customerId': 'cliente-$id',
    'machineIds': maquinas,
    'startsAt': DateTime(2026, 8, inicioDia).toIso8601String(),
    'endsAt': DateTime(2026, 8, fimDia).toIso8601String(),
    'status': estado,
    'companyId': 'empresa',
    'customerNameSnapshot': 'Cliente $id',
    'collaboratorNameSnapshot': '',
    'collaboratorResponsibleId': responsavel,
    'notes': '',
  };

  void guardarLocal(Map<String, dynamic> dados) {
    // Chega pelo caminho remoto para entrar no estado sem disparar detecção
    // contra si própria — o primeiro a chegar nunca colide com nada.
    repo.aplicarOperacaoRemota('booking', dados);
    detectados.clear();
  }

  test('a mesma máquina prometida duas vezes é assinalada', () {
    guardarLocal(reserva(id: 'r1', maquinas: ['giratoria'], inicioDia: 1, fimDia: 10));

    repo.aplicarOperacaoRemota(
      'booking',
      reserva(id: 'r2', maquinas: ['giratoria'], inicioDia: 5, fimDia: 15),
    );

    expect(detectados, hasLength(1));
    expect(detectados.single.machineIdsPartilhados, ['giratoria']);
    expect(detectados.single.estado, EstadoConflito.pendente);
    expect(
      {detectados.single.entidadeAId, detectados.single.entidadeBId},
      {'r1', 'r2'},
    );
  });

  test('a reserva que chega é gravada na mesma — assinalar não é bloquear', () {
    guardarLocal(reserva(id: 'r1', maquinas: ['giratoria'], inicioDia: 1, fimDia: 10));

    repo.aplicarOperacaoRemota(
      'booking',
      reserva(id: 'r2', maquinas: ['giratoria'], inicioDia: 5, fimDia: 15),
    );

    // As duas ficam no estado: quem decide qual vale é uma pessoa, e para
    // decidir tem de as ver às duas.
    expect(repo.bookings.map((b) => b.id), containsAll(['r1', 'r2']));
  });

  test('máquinas diferentes ao mesmo tempo não são conflito', () {
    guardarLocal(reserva(id: 'r1', maquinas: ['giratoria'], inicioDia: 1, fimDia: 10));

    repo.aplicarOperacaoRemota(
      'booking',
      reserva(id: 'r2', maquinas: ['martelo'], inicioDia: 1, fimDia: 10),
    );

    expect(detectados, isEmpty);
  });

  test('a mesma máquina em datas que não se tocam não é conflito', () {
    guardarLocal(reserva(id: 'r1', maquinas: ['giratoria'], inicioDia: 1, fimDia: 5));

    repo.aplicarOperacaoRemota(
      'booking',
      reserva(id: 'r2', maquinas: ['giratoria'], inicioDia: 10, fimDia: 15),
    );

    expect(detectados, isEmpty);
  });

  test('entregar no dia em que o outro recolhe não é conflito', () {
    // Fim exclusivo: a reserva que acaba dia 5 liberta a máquina para a que
    // começa dia 5. Marcar isto como disputa ensinava o gestor a ignorar
    // avisos.
    guardarLocal(reserva(id: 'r1', maquinas: ['giratoria'], inicioDia: 1, fimDia: 5));

    repo.aplicarOperacaoRemota(
      'booking',
      reserva(id: 'r2', maquinas: ['giratoria'], inicioDia: 5, fimDia: 9),
    );

    expect(detectados, isEmpty);
  });

  test('um pedido por confirmar ainda não prende a máquina', () {
    guardarLocal(reserva(id: 'r1', maquinas: ['giratoria'], inicioDia: 1, fimDia: 10));

    repo.aplicarOperacaoRemota(
      'booking',
      reserva(
        id: 'r2',
        maquinas: ['giratoria'],
        inicioDia: 5,
        fimDia: 15,
        estado: 'request',
      ),
    );

    expect(detectados, isEmpty);
  });

  test('uma reserva cancelada não disputa nada', () {
    guardarLocal(
      reserva(
        id: 'r1',
        maquinas: ['giratoria'],
        inicioDia: 1,
        fimDia: 10,
        estado: 'cancelled',
      ),
    );

    repo.aplicarOperacaoRemota(
      'booking',
      reserva(id: 'r2', maquinas: ['giratoria'], inicioDia: 5, fimDia: 15),
    );

    expect(detectados, isEmpty);
  });

  test('editar a mesma reserva noutro aparelho não é conflito consigo própria',
      () {
    guardarLocal(reserva(id: 'r1', maquinas: ['giratoria'], inicioDia: 1, fimDia: 10));

    repo.aplicarOperacaoRemota(
      'booking',
      reserva(id: 'r1', maquinas: ['giratoria'], inicioDia: 2, fimDia: 11),
    );

    expect(detectados, isEmpty);
  });

  test('o id da disputa é o mesmo nos dois aparelhos', () {
    // Cada aparelho detecta a mesma disputa por sua conta, em ordens
    // diferentes. Se gerassem ids diferentes, resolver num não resolvia no
    // outro.
    guardarLocal(reserva(id: 'r1', maquinas: ['giratoria'], inicioDia: 1, fimDia: 10));
    repo.aplicarOperacaoRemota(
      'booking',
      reserva(id: 'r2', maquinas: ['giratoria'], inicioDia: 5, fimDia: 15),
    );
    final visaoDoGestor = detectados.single.id;

    expect(visaoDoGestor, 'reservaMaquina:r1:r2');
  });

  test('guarda quem estava envolvido, para se saber com quem falar', () {
    guardarLocal(
      reserva(
        id: 'r1',
        maquinas: ['giratoria'],
        inicioDia: 1,
        fimDia: 10,
        responsavel: 'joao',
      ),
    );

    repo.aplicarOperacaoRemota(
      'booking',
      reserva(
        id: 'r2',
        maquinas: ['giratoria'],
        inicioDia: 5,
        fimDia: 15,
        responsavel: 'maria',
      ),
    );

    expect(detectados.single.envolvidos, containsAll(['joao', 'maria']));
  });
}
