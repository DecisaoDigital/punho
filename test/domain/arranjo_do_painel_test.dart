import 'package:flutter_test/flutter_test.dart';
import 'package:punho/domain/models/arranjo_do_painel.dart';

/// **O painel do gestor: o que lá está e por que ordem.**
///
/// O que se defende aqui é sobretudo o que *não* se perde. Um arranjo que
/// esquecesse coisas ao desmarcar, ou ao reordenar, ou ao ler de volta o que
/// gravou, não daria erro nenhum — o gestor é que voltaria ao painel e
/// encontrava-o arrumado de outra maneira, sem saber porquê.
void main() {
  group('o painel nasce vazio', () {
    test('sem escolha nenhuma não mostra nada', () {
      expect(ArranjoDoPainel.vazio.noPainel, isEmpty);
      expect(ArranjoDoPainel.vazio.estaVazio, isTrue);
    });

    test('vazio não é o catálogo todo por omissão', () {
      // A tentação era "começar com uns quantos para não parecer partido".
      // Seria a app a dizer o que interessa ao negócio dele sem saber nada
      // dele — e a encher o painel de células a dizer "aguarda".
      expect(ArranjoDoPainel.vazio.contem('caixa'), isFalse);
    });
  });

  group('marcar e desmarcar', () {
    test('o que se marca sobe ao painel', () {
      final a = ArranjoDoPainel.vazio.comEscolha('caixa', escolher: true);
      expect(a.noPainel, ['caixa']);
    });

    test('quem entra vai para o fim da fila', () {
      final a = ArranjoDoPainel.vazio
          .comEscolha('caixa', escolher: true)
          .comEscolha('entradas-mes', escolher: true);
      expect(a.noPainel, ['caixa', 'entradas-mes']);
    });

    test('desmarcar não apaga o lugar que ele tinha', () {
      // O caso real: tira-se um do meio para ver o painel sem ele, e põe-se
      // outra vez. Se o lugar se perdesse, voltava para o fim — e a
      // arrumação que ele fez à mão desfazia-se um KPI de cada vez.
      final a = ArranjoDoPainel.vazio
          .comEscolha('caixa', escolher: true)
          .comEscolha('entradas-mes', escolher: true)
          .comEscolha('encontro-contas', escolher: true);

      final semMeio = a.comEscolha('entradas-mes', escolher: false);
      expect(semMeio.noPainel, ['caixa', 'encontro-contas']);

      expect(semMeio.comEscolha('entradas-mes', escolher: true).noPainel, [
        'caixa',
        'entradas-mes',
        'encontro-contas',
      ]);
    });

    test('marcar duas vezes o mesmo não o duplica', () {
      final a = ArranjoDoPainel.vazio
          .comEscolha('caixa', escolher: true)
          .comEscolha('caixa', escolher: true);
      expect(a.noPainel, ['caixa']);
    });
  });

  group('arrastar para ordenar', () {
    final tres = ArranjoDoPainel.vazio
        .comEscolha('caixa', escolher: true)
        .comEscolha('entradas-mes', escolher: true)
        .comEscolha('encontro-contas', escolher: true);

    test('a ordem da lista é a ordem do painel', () {
      final arrastado = tres.comOrdem([
        'encontro-contas',
        'caixa',
        'entradas-mes',
      ]);
      expect(arrastado.noPainel, ['encontro-contas', 'caixa', 'entradas-mes']);
    });

    test('arrastar não marca nem desmarca ninguém', () {
      final comUmDeFora = tres.comEscolha('caixa', escolher: false);
      final arrastado = comUmDeFora.comOrdem([
        'caixa',
        'encontro-contas',
        'entradas-mes',
      ]);
      expect(arrastado.contem('caixa'), isFalse);
      expect(arrastado.noPainel, ['encontro-contas', 'entradas-mes']);
    });

    test('o que hoje não está pronto fica onde estava, não vai para o fim', () {
      // A lista que se arrasta só tem os prontos. Um KPI que ficou sem dados
      // desapareceu de lá — e empurrá-lo para o fim é tão mau como deitá-lo
      // fora: no dia 1 do mês meio catálogo cai de uma vez, e bastaria um
      // arrasto para o painel dele ficar todo trocado sem ele lhe tocar.
      //
      // Aqui: 'entradas-mes' estava atrás de 'caixa'. A lista nova troca
      // 'caixa' e 'encontro-contas', e ele continua **atrás da caixa**.
      final semOMeio = tres.comOrdem(['encontro-contas', 'caixa']);
      expect(semOMeio.contem('entradas-mes'), isTrue);
      expect(semOMeio.noPainel, ['encontro-contas', 'caixa', 'entradas-mes']);
    });

    test('o ausente que estava à cabeça continua à cabeça', () {
      // Sem vizinho anterior a que se agarrar. Mandá-lo para o fim invertia a
      // leitura do painel de uma ponta à outra.
      final semOPrimeiro = tres.comOrdem(['entradas-mes', 'encontro-contas']);
      expect(semOPrimeiro.noPainel, [
        'caixa',
        'entradas-mes',
        'encontro-contas',
      ]);
    });

    test('dois ausentes seguidos mantêm a ordem entre si', () {
      final quatro = tres.comEscolha('reservas-activas', escolher: true);
      // Só 'caixa' e 'reservas-activas' estão prontos; os dois do meio caíram.
      final arrastado = quatro.comOrdem(['reservas-activas', 'caixa']);
      expect(arrastado.noPainel, [
        'reservas-activas',
        'caixa',
        'entradas-mes',
        'encontro-contas',
      ]);
    });
  });

  group('arrumar a lista que se mostra', () {
    test('a ordem do gestor manda; o resto vem pelo catálogo', () {
      final a = ArranjoDoPainel.vazio.comOrdem(['ticket-medio-mes', 'caixa']);
      expect(a.arrumar(['caixa', 'entradas-mes', 'ticket-medio-mes']), [
        'ticket-medio-mes',
        'caixa',
        'entradas-mes',
      ]);
    });

    test('sem arranjo nenhum, fica como veio', () {
      expect(ArranjoDoPainel.vazio.arrumar(['b', 'a', 'c']), ['b', 'a', 'c']);
    });
  });

  group('o que se gravou volta como estava', () {
    test('ida e volta pelo JSON', () {
      final a = ArranjoDoPainel.vazio
          .comEscolha('caixa', escolher: true)
          .comEscolha('entradas-mes', escolher: true)
          .comEscolha('caixa', escolher: false);

      expect(ArranjoDoPainel.fromJson(a.toJson()), a);
    });

    test('sem nada gravado, o painel está vazio e não parte', () {
      expect(ArranjoDoPainel.fromJson(null), ArranjoDoPainel.vazio);
      expect(ArranjoDoPainel.fromJson(const {}), ArranjoDoPainel.vazio);
    });

    test('lixo no sítio das listas lê-se como lista vazia', () {
      final a = ArranjoDoPainel.fromJson(const {
        'ordem': 'caixa',
        'escolhidos': 7,
      });
      expect(a, ArranjoDoPainel.vazio);
    });

    test('um marcado que não conste da arrumação continua a ver-se', () {
      // Gravação de uma versão mais velha, ou meio escrita. Ficar marcado e
      // invisível era o pior dos dois mundos: no painel não aparecia, e na
      // bancada a caixa dizia que sim.
      final a = ArranjoDoPainel.fromJson(const {
        'ordem': ['caixa'],
        'escolhidos': ['caixa', 'entradas-mes'],
      });
      expect(a.noPainel, ['caixa', 'entradas-mes']);
    });
  });
}
