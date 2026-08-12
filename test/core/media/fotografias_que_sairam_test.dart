import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/media/machine_image_store.dart';

/// **Uma fotografia de máquina que sai da lista tem de sair também do arquivo.**
///
/// Encontrado ao fechar o achado 3.7: `<empresa>/machines/` tinha política de
/// leitura e de envio e nenhuma de apagar, e a app nem sequer tinha por onde
/// pedir. Trocar a fotografia de uma máquina deixava a antiga no balde para
/// sempre — no mesmo balde de 1 GB de onde saem os APKs.
///
/// O risco desta correcção não é técnico, é de decidir mal **o que** apagar:
/// apagar de menos deixa lixo, apagar de mais leva uma fotografia que ainda
/// está a ser usada. É por isso que essa decisão vive numa função pura e é
/// aqui que se prende.
void main() {
  List<String> remover(List<String> antes, List<String> depois) =>
      MachineImageStore.caminhosARemover(antes: antes, depois: depois);

  const a = 'remote://empresa-1/machines/111.jpg';
  const b = 'remote://empresa-1/machines/222.jpg';

  test('o que saiu da lista é apagado, sem o prefixo', () {
    expect(remover([a, b], [b]), ['empresa-1/machines/111.jpg']);
  });

  test('o que ficou não se toca', () {
    expect(remover([a, b], [a, b]), isEmpty);
  });

  test('acrescentar uma fotografia não apaga nada', () {
    expect(remover([a], [a, b]), isEmpty);
  });

  test('esvaziar a lista apaga tudo o que lá estava', () {
    expect(remover([a, b], const []), hasLength(2));
  });

  test('reordenar não é apagar', () {
    // A lista é ordenada — a primeira é a principal. Trocar a ordem mexe no
    // que se mostra, não no que existe.
    expect(remover([a, b], [b, a]), isEmpty);
  });

  test('caminhos locais ficam de fora', () {
    // Uma fotografia acabada de tirar ainda não subiu. Não está no arquivo, e
    // mandar apagá-la seria pedir ao servidor que apagasse algo que não tem.
    const local = '/data/user/0/pt.decisaodigital.punho/machine_9.jpg';
    expect(remover([local, a], const []), ['empresa-1/machines/111.jpg']);
  });

  test('a mesma fotografia repetida não se manda apagar duas vezes', () {
    expect(remover([a, a], const []), hasLength(1));
  });

  test('uma máquina nova não tem nada para apagar', () {
    expect(remover(const [], [a]), isEmpty);
  });
}
