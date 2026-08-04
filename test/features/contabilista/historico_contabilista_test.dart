import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/contabilista/data/contabilista_service.dart';
import 'package:punho/features/contabilista/domain/contabilista.dart';
import 'package:punho/features/tarefas/data/tarefas_service.dart';
import 'package:punho/features/tarefas/domain/tarefa.dart';

import '../dashboard/fixtura.dart';

void main() {
  group('Lacunas viram tarefas', () {
    LacunaContabilista lacuna({
      String rubrica = 'facturacao',
      String rotulo = 'Faturação do mês',
      PeriodicidadeRubrica periodicidade = PeriodicidadeRubrica.mensal,
      int emFalta = 0,
      int soAnual = 0,
      DateTime? primeiro,
      DateTime? ultimo,
    }) => LacunaContabilista(
      rubrica: rubrica,
      rotulo: rotulo,
      periodicidade: periodicidade,
      emFalta: emFalta,
      soAnual: soAnual,
      primeiroMes: primeiro,
      ultimoMes: ultimo,
    );

    test('meses em branco são pendência, meses só anuais são sugestão', () {
      final tarefas = tarefasPendentes(
        estadoComMovimento(),
        agoraFixa,
        lacunas: [
          lacuna(
            emFalta: 42,
            soAnual: 16,
            primeiro: DateTime(2021, 9),
            ultimo: DateTime(2026, 7),
          ),
        ],
      );

      final falta = tarefas.firstWhere((t) => t.id == 'historico-facturacao');
      expect(falta.severidade, SeveridadeTarefa.aCompletar);
      expect(falta.titulo, 'Faltam 42 meses de faturação do mês');
      expect(falta.subtitulo, contains('entre 2021 e 2026'));
      expect(falta.destino, DestinoTarefa.historicoContabilista);
      expect(falta.referencia, 'facturacao');

      final anual = tarefas.firstWhere(
        (t) => t.id == 'historico-anual-facturacao',
      );
      // Sugestão e não pendência: o painel já usa o total repartido, não há
      // nada partido à espera desta.
      expect(anual.severidade, SeveridadeTarefa.sugestao);
      expect(anual.titulo, contains('16 meses só com o total do ano'));
      expect(anual.referencia, 'facturacao');
    });

    test('uma rubrica resolvida não gera tarefa nenhuma', () {
      final tarefas = tarefasPendentes(
        estadoComMovimento(),
        agoraFixa,
        lacunas: [lacuna()],
      );
      expect(
        tarefas.where((t) => t.id.startsWith('historico-')),
        isEmpty,
      );
    });

    test('singular quando falta um mês só', () {
      final tarefas = tarefasPendentes(
        estadoComMovimento(),
        agoraFixa,
        lacunas: [
          lacuna(emFalta: 1, primeiro: DateTime(2024, 3), ultimo: DateTime(2024, 3)),
        ],
      );
      final t = tarefas.firstWhere((t) => t.id == 'historico-facturacao');
      expect(t.titulo, 'Falta 1 mês de faturação do mês');
      // Um buraco que cabe todo num ano não se lê "entre 2024 e 2024".
      expect(t.subtitulo, contains('em 2024'));
    });

    test('rubrica de resposta única não fala em meses', () {
      final tarefas = tarefasPendentes(
        estadoComMovimento(),
        agoraFixa,
        lacunas: [
          lacuna(
            rubrica: 'periodicidade_iva',
            rotulo: 'Periodicidade do IVA',
            periodicidade: PeriodicidadeRubrica.unica,
            emFalta: 1,
          ),
        ],
      );
      final t = tarefas.firstWhere(
        (t) => t.id == 'historico-periodicidade_iva',
      );
      expect(t.titulo, 'Periodicidade do IVA — por responder');
      expect(t.subtitulo, isNot(contains('mês')));
      expect(t.subtitulo, isNot(contains('meses')));
    });

    test('sem lacunas nenhumas, nada muda nas outras tarefas', () {
      final semLacunas = tarefasPendentes(estadoComMovimento(), agoraFixa);
      final comListaVazia = tarefasPendentes(
        estadoComMovimento(),
        agoraFixa,
        lacunas: const [],
      );
      expect(
        comListaVazia.map((t) => t.id),
        semLacunas.map((t) => t.id),
      );
    });
  });

  group('Convite', () {
    ConviteCriado criado({DateTime? expira}) => ConviteCriado(
      token: 'a' * 64,
      conviteId: 'id',
      mesInicial: DateTime(2021, 9),
      mesFinal: DateTime(2026, 7),
      expiraEm: expira ?? DateTime(2026, 11, 2),
    );

    test('o link aponta à Edge Function, com o token na query', () {
      final url = linkContabilista('abc123');
      expect(url, contains('/functions/v1/portal-contabilista'));
      expect(url, endsWith('?t=abc123'));
    });

    test('a mensagem diz o período, o que fazer com o que não se sabe, e o prazo', () {
      final texto = mensagemContabilista(criado(), empresa: 'Lavandaria Mare Alta');
      expect(texto, contains('Lavandaria Mare Alta'));
      expect(texto, contains('Setembro de 2021'));
      expect(texto, contains('Julho de 2026'));
      // O que ele precisa de saber para não inventar zeros.
      expect(texto, contains('em branco não é zero'));
      // E que pode voltar — senão tenta responder a tudo de uma vez e desiste.
      expect(texto, contains('voltar ao mesmo link'));
      expect(texto, contains('02/11/2026'));
    });

    test('sem nome de empresa a mensagem continua a ler-se', () {
      final texto = mensagemContabilista(criado(), empresa: '   ');
      expect(texto, contains('histórico de a empresa'));
      expect(texto, isNot(contains('null')));
    });

    group('estado deriva-se das datas', () {
      ConviteContabilista convite({
        DateTime? aberto,
        DateTime? submetido,
        DateTime? revogado,
        DateTime? expira,
      }) => ConviteContabilista(
        id: 'id',
        mesInicial: DateTime(2021, 9),
        mesFinal: DateTime(2026, 7),
        criadoEm: DateTime(2026, 8, 4),
        expiraEm: expira ?? DateTime(2026, 11, 2),
        abertoEm: aberto,
        submetidoEm: submetido,
        revogadoEm: revogado,
      );

      final agora = DateTime(2026, 8, 10);

      test('revogado ganha a tudo o resto', () {
        // Submetido e revogado ao mesmo tempo: o que interessa é que o link
        // deixou de abrir.
        expect(
          convite(
            submetido: DateTime(2026, 8, 6),
            revogado: DateTime(2026, 8, 7),
          ).estadoEm(agora),
          EstadoConvite.revogado,
        );
      });

      test('expirado ganha ao submetido', () {
        expect(
          convite(
            submetido: DateTime(2026, 8, 6),
            expira: DateTime(2026, 8, 9),
          ).estadoEm(agora),
          EstadoConvite.expirado,
        );
      });

      test('entregue mas ainda vivo — ele pode voltar a corrigir', () {
        final c = convite(
          aberto: DateTime(2026, 8, 5),
          submetido: DateTime(2026, 8, 6),
        );
        expect(c.estadoEm(agora), EstadoConvite.submetido);
        expect(c.estadoEm(agora).vivo, isTrue);
      });

      test('aberto e ainda a preencher', () {
        expect(
          convite(aberto: DateTime(2026, 8, 5)).estadoEm(agora),
          EstadoConvite.aberto,
        );
      });

      test('emitido e nunca aberto', () {
        expect(convite().estadoEm(agora), EstadoConvite.porAbrir);
      });
    });

    test('sem nome nem email, a designação é a data de emissão', () {
      final c = ConviteContabilista(
        id: 'id',
        mesInicial: DateTime(2021, 9),
        mesFinal: DateTime(2026, 7),
        criadoEm: DateTime(2026, 8, 4),
        expiraEm: DateTime(2026, 11, 2),
      );
      expect(c.designacao, 'Convite de 04/08');
      expect(
        ConviteContabilista(
          id: 'id',
          nome: '  ',
          email: 'ana@contab.pt',
          mesInicial: DateTime(2021, 9),
          mesFinal: DateTime(2026, 7),
          criadoEm: DateTime(2026, 8, 4),
          expiraEm: DateTime(2026, 11, 2),
        ).designacao,
        'ana@contab.pt',
      );
    });
  });
}
