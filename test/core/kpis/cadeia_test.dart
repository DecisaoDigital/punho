import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/dashboard/presentation/kpi_catalogo.dart';

/// **A cadeia de KPIs tem de ser uma árvore.**
///
/// É a ideia central do plano de KPIs: um número mau tem de ter um filho que o
/// explique. Isso só funciona se a estrutura for mesmo uma árvore — um pai que
/// não existe deixa um ramo pendurado no ar, e um ciclo pendura a app.
///
/// Estes testes não olham para números nenhuns. Olham para a forma, que é o que
/// se parte quando alguém acrescenta um KPI ao catálogo e se esquece do `pai`.
void main() {
  group('a forma da árvore', () {
    test('todo o pai apontado existe no catálogo', () {
      final ids = {for (final k in catalogoKpis) k.id};
      for (final k in catalogoKpis) {
        final pai = k.pai;
        if (pai == null) continue;
        expect(
          ids,
          contains(pai),
          reason: '«${k.id}» diz que o pai é «$pai», e esse KPI não existe',
        );
      }
    });

    test('nenhum KPI é pai de si próprio', () {
      for (final k in catalogoKpis) {
        expect(k.pai, isNot(k.id), reason: '«${k.id}» aponta para si mesmo');
      }
    });

    test('não há ciclos — toda a subida acaba numa raiz', () {
      for (final k in catalogoKpis) {
        final caminho = caminhoAteARaiz(k.id);
        expect(
          caminho.last.pai,
          isNull,
          reason:
              'a subida a partir de «${k.id}» acabou em «${caminho.last.id}», '
              'que ainda tem pai — é um ciclo',
        );
      }
    });

    test('os ids são únicos', () {
      final vistos = <String>{};
      for (final k in catalogoKpis) {
        expect(vistos.add(k.id), isTrue, reason: '«${k.id}» está repetido');
      }
    });
  });

  group('a cadeia que o plano desenhou', () {
    test('a Caixa é a raiz — é aí que a leitura começa', () {
      expect(kpiPorId('caixa')!.pai, isNull);
    });

    test('as Vendas explicam o Lucro, e o Lucro explica a Caixa', () {
      expect(caminhoAteARaiz('vendas-mes').map((k) => k.id), [
        'vendas-mes',
        'lucro-mes',
        'caixa',
      ]);
    });

    test('o Lucro tem as Vendas e a Estrutura por baixo', () {
      // É este par que faz o ecrã de atenção poder dizer «as vendas
      // mantiveram-se, o que subiu foi a estrutura».
      final filhos = filhosDe('lucro-mes').map((k) => k.id);
      expect(filhos, containsAll(['vendas-mes', 'estrutura-mes']));
    });

    test('o funil pendura-se nas Vendas, pela ordem em que acontece', () {
      expect(caminhoAteARaiz('leads-pipeline').map((k) => k.id), [
        'leads-pipeline',
        'conversao-lead-cliente',
        'vendas-mes',
        'lucro-mes',
        'caixa',
      ]);
    });

    test('quase nada fica solto — e o que fica, fica por bom motivo', () {
      // A recomendação não explica nenhum número: lê todos e sugere um passo.
      // Pendurá-la num pai era mentir sobre o que ela faz.
      //
      // O lucro do mês anterior fica solto pela razão simétrica: não é uma
      // parcela do mês corrente, é a régua com que se lê. Como filho do Lucro
      // do mês apareceria na lista do «o que está por trás deste número», e o
      // mês passado não está por trás de nada — está ao lado.
      expect(raizesDaCadeia.map((k) => k.id), [
        'lucro-mes-anterior',
        'caixa',
        'recomendacao-dia',
      ]);
    });

    test('a Estrutura desdobra-se no que ainda falta pagar este mês', () {
      // Quem vê a estrutura a subir quer logo saber quanto falta sair até ao
      // fim do mês. É o passo seguinte natural, e por isso é filho.
      expect(filhosDe('estrutura-mes').map((k) => k.id), [
        'gastos-previstos-mes',
      ]);
    });

    test('nenhuma folha é um beco — todas levam a algum lado', () {
      // A cadeia serve para descer de um número mau até uma acção. Uma folha
      // sem destino corta o caminho no último passo: o gestor percebe o
      // problema e fica ali a olhar para ele. Este teste apanhou três — as
      // cobranças a vencer, as entregas de hoje e as recolhas a fazer — todas
      // sem para onde ir.
      final becos = [
        for (final k in catalogoKpis)
          if (filhosDe(k.id).isEmpty && k.destino == null) k.id,
      ];
      expect(
        becos,
        // Duas excepções, ambas honestas. A satisfação do cliente: a app ainda
        // não sabe fazer a pergunta ao cliente, portanto não há ecrã para onde
        // mandar ninguém — está dito no próprio `desbloqueio`. A recomendação
        // do dia: já é ela o destino, aponta para onde agir em vez de ter um
        // sítio próprio.
        ['recomendacao-dia', 'satisfacao-cliente'],
        reason: 'folhas sem destino: $becos',
      );
    });
  });

  group('os utilitários', () {
    test('paiDe devolve a definição, não o id', () {
      expect(paiDe('vendas-mes')?.titulo, 'Lucro do mês');
      expect(paiDe('caixa'), isNull);
    });

    test('um id que não existe não rebenta nada', () {
      expect(caminhoAteARaiz('nao-existe'), isEmpty);
      expect(filhosDe('nao-existe'), isEmpty);
      expect(paiDe('nao-existe'), isNull);
    });
  });
}
