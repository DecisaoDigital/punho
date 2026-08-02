import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/workforce/presentation/workforce_pages.dart';

/// A frase do cabeçalho de Funcionários, incluindo o caso que motivou a
/// decisão de 2026-08-02: a subscrição no servidor pode descer abaixo de
/// quem já está ativo (Lavandaria Mare Alta: limite 1, três já ativos).
void main() {
  test('vaga no singular, não "1 vagas"', () {
    expect(
      mensagemVagasDeColaboradores(1, 1),
      '1 colaboradores ativos de 1 vaga contratada',
    );
  });

  test('vagas no plural com mais do que uma', () {
    expect(
      mensagemVagasDeColaboradores(2, 5),
      '2 colaboradores ativos de 5 vagas contratadas',
    );
  });

  test(
    'mais ativos do que vagas: diz que não há vagas livres, sem fingir que '
    'os números batem certo',
    () {
      final mensagem = mensagemVagasDeColaboradores(3, 1);
      expect(mensagem, contains('3 colaboradores ativos'));
      expect(mensagem, contains('sem vagas livres'));
      expect(mensagem, contains('1 vaga contratada'));
      // Não é "de 1 vaga contratada" como no caso normal — teria a mesma
      // forma de uma frase que bate certo, e não bate.
      expect(mensagem, isNot(contains('de 1 vaga contratada')));
    },
  );

  test('no limite exato ainda é a frase normal, não a de excesso', () {
    expect(
      mensagemVagasDeColaboradores(3, 3),
      '3 colaboradores ativos de 3 vagas contratadas',
    );
  });
}
