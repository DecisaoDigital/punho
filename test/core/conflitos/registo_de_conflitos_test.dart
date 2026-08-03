import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/conflitos/registo_de_conflitos.dart';
import 'package:punho/domain/models/conflito_pendente.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<RegistoDeConflitos> registo() async {
    SharedPreferences.setMockInitialValues({});
    return RegistoDeConflitos(await SharedPreferences.getInstance());
  }

  ConflitoPendente conflito({String a = 'reserva-a', String b = 'reserva-b'}) =>
      ConflitoPendente.reservaMaquina(
        reservaId1: a,
        reservaId2: b,
        machineIdsPartilhados: const ['m1'],
        envolvidos: const ['colab-1', 'colab-2'],
        criadoEm: DateTime(2026, 8, 3),
      );

  test('guardarLocal aparece em todos, pendentes e porEnviar', () async {
    final r = await registo();
    final c = conflito();

    await r.guardarLocal(c);

    expect(r.todos.single.id, c.id);
    expect(r.pendentes.single.id, c.id);
    expect(r.porEnviar.single.id, c.id);
  });

  test('aplicarRemoto guarda mas não marca para envio', () async {
    // Sem isto, aplicar o que veio do servidor reenviava-o de volta — eco
    // sem fim entre dois aparelhos, mesmo motivo do `aoRegistarOperacao`.
    final r = await registo();
    final c = conflito();

    await r.aplicarRemoto(c);

    expect(r.todos.single.id, c.id);
    expect(r.porEnviar, isEmpty);
  });

  test('nunca reabre um conflito já resolvido', () async {
    final r = await registo();
    final pendente = conflito();
    final resolvido = pendente.resolvidoComo(
      ficaComEntidadeId: pendente.entidadeAId,
      resolvidoPor: 'user-gestor',
      resolvidoEm: DateTime(2026, 8, 3, 12),
    );

    await r.guardarLocal(resolvido);
    // Reentrega tardia da mesma disputa, ainda com estado pendente (ex.:
    // `carregarTudoParaFila` a reprocessar histórico).
    await r.guardarLocal(pendente);

    expect(r.porId(pendente.id)!.estado, EstadoConflito.resolvido);
    expect(r.pendentes, isEmpty);
  });

  test('marcarEnviados esvazia porEnviar sem apagar o conflito', () async {
    final r = await registo();
    final c = conflito();
    await r.guardarLocal(c);

    await r.marcarEnviados({c.id});

    expect(r.porEnviar, isEmpty);
    expect(r.todos.single.id, c.id);
  });

  test('fica gravado no telemóvel entre instâncias', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = conflito();
    await RegistoDeConflitos(prefs).guardarLocal(c);

    final outro = RegistoDeConflitos(prefs);

    expect(outro.todos.single.id, c.id);
    expect(outro.porEnviar.single.id, c.id);
  });

  test('dois conflitos diferentes convivem sem se pisarem', () async {
    final r = await registo();
    final c1 = conflito(a: 'reserva-a', b: 'reserva-b');
    final c2 = conflito(a: 'reserva-c', b: 'reserva-d');

    await r.guardarLocal(c1);
    await r.guardarLocal(c2);

    expect(r.todos.map((c) => c.id), containsAll([c1.id, c2.id]));
    expect(r.todos.length, 2);
  });
}
