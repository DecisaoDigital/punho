import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/licenca/machine_id.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('primeiro arranque calcula o hash e guarda-o em cache', () async {
    final id = await resolverMachineId(
      semente: () async => 'windows:PC-1:guid',
    );

    // SHA256 em hexadecimal.
    expect(id, hasLength(64));
    expect(id, matches(RegExp(r'^[0-9a-f]{64}$')));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(chaveMachineId), id);
  });

  test('arranques seguintes reutilizam a cache e não recalculam', () async {
    var vezes = 0;
    Future<String> semente() async {
      vezes++;
      return 'windows:PC-1:guid';
    }

    final primeiro = await resolverMachineId(semente: semente);
    final segundo = await resolverMachineId(semente: semente);

    expect(segundo, primeiro);
    expect(vezes, 1, reason: 'a semente só deve ser lida uma vez');
  });

  test('a mesma semente produz sempre o mesmo identificador', () async {
    final primeiro = await resolverMachineId(
      semente: () async => 'android:xyz',
    );

    SharedPreferences.setMockInitialValues({});
    final segundo = await resolverMachineId(semente: () async => 'android:xyz');

    expect(segundo, primeiro);
  });

  test('sementes diferentes produzem identificadores diferentes', () async {
    final windows = await resolverMachineId(
      semente: () async => 'windows:PC-1:guid',
    );

    SharedPreferences.setMockInitialValues({});
    final android = await resolverMachineId(semente: () async => 'android:xyz');

    expect(android, isNot(windows));
  });

  test('a semente do Android não é o Build.ID', () async {
    // Era `androidInfo.id` — o identificador da ROM, `TKQ1.221013.002` no
    // Redmi. Dois aparelhos com a mesma MIUI davam o mesmo terminal e, por
    // consequência, a mesma licença. O que identifica um aparelho é o
    // ANDROID_ID, que é por (aparelho, chave de assinatura) e sobrevive a uma
    // reinstalação.
    final romPartilhada = await resolverMachineId(
      semente: () async => 'android:TKQ1.221013.002',
    );

    SharedPreferences.setMockInitialValues({});
    final aparelhoReal = await resolverMachineId(
      semente: () async => 'android:9774d56d682e549c',
    );

    expect(aparelhoReal, isNot(romPartilhada));
  });

  test('cache curta ou corrompida é descartada e recalculada', () async {
    SharedPreferences.setMockInitialValues({chaveMachineId: 'curto'});

    final id = await resolverMachineId(
      semente: () async => 'windows:PC-1:guid',
    );

    expect(id, hasLength(64));
  });
}
