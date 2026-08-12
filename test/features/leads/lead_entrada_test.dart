import 'package:flutter_test/flutter_test.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/leads/data/leads_entrada_service.dart';
import 'package:punho/features/tarefas/data/tarefas_service.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/features/tarefas/domain/tarefa.dart';

/// Entrada de leads vindas de fora. Ver `docs/ENTRADA_DE_LEADS.md`.
void main() {
  Map<String, dynamic> linha({
    String? nome,
    String origem = 'landing_page',
    String classificacao = 'aceite',
    String? telefone = '+351912345678',
    String? mensagem,
    String? baseLegal = 'consentimento',
  }) => {
    'id': 'e1',
    'origem': origem,
    'classificacao': classificacao,
    'recebida_em': '2026-07-10T09:00:00.000Z',
    'nome': nome,
    'telefone_e164': telefone,
    'mensagem': mensagem,
    'base_legal': baseLegal,
  };

  group('LeadEntrada', () {
    test('a origem do servidor vira origem da lead', () {
      expect(LeadEntrada.fromJson(linha()).origem, LeadSource.landingPage);
      expect(
        LeadEntrada.fromJson(linha(origem: 'whatsapp')).origem,
        LeadSource.whatsapp,
      );
      // Uma origem que a app ainda não conhece não pode rebentar a leitura: uma
      // versão nova do servidor não deve partir uma app antiga.
      expect(
        LeadEntrada.fromJson(linha(origem: 'canal_do_futuro')).origem,
        LeadSource.other,
      );
    });

    test('sem nome, o telefone identifica', () {
      expect(LeadEntrada.fromJson(linha()).nomeParaMostrar, '+351912345678');
      expect(
        LeadEntrada.fromJson(linha(nome: '  Ana  ')).nomeParaMostrar,
        'Ana',
      );
    });

    test('a data da lead é a da chegada, não a de quando a app a puxou', () {
      // É o que faz o "sem contacto há mais de N dias" medir tempo de resposta
      // a sério. Com a data da recolha, uma lead de há uma semana entrava como
      // acabada de chegar e o atraso desaparecia.
      final lead = LeadEntrada.fromJson(linha()).paraLead('l1');

      expect(lead.createdAt, DateTime.parse('2026-07-10T09:00:00.000Z'));
      expect(lead.status, LeadStatus.newLead);
      expect(lead.source, LeadSource.landingPage);
    });

    test('a mensagem do formulário fica no resumo', () {
      final lead = LeadEntrada.fromJson(
        linha(mensagem: 'Preciso de uma mini escavadora'),
      ).paraLead('l1');

      expect(lead.summary, 'Preciso de uma mini escavadora');
    });

    test('só a aceite entra sozinha no pipeline', () {
      expect(LeadEntrada.fromJson(linha()).aceite, isTrue);
      expect(
        LeadEntrada.fromJson(linha(classificacao: 'retida')).aceite,
        isFalse,
      );
    });
  });

  // Achado 3.4. Entrar sozinha no pipeline é copiar uma pessoa para dentro do
  // log de operações, que é append-only: lá dentro apagar deixa de ser apagar e
  // passa a ser redigir. Duas perguntas têm de dar que sim — o servidor aceitou,
  // e há alguma coisa que autorize guardar aquilo.
  group('base legal', () {
    test('sem base legal registada não entra sozinha, mesmo dita aceite', () {
      final semBase = LeadEntrada.fromJson(linha(baseLegal: 'nao_registada'));

      expect(semBase.classificacao, 'aceite');
      expect(semBase.temBaseLegal, isFalse);
      expect(semBase.aceite, isFalse);
    });

    test('quem nos procurou tem base própria e não precisa de consentimento', () {
      // Ligar a pedir orçamento é diligência pré-contratual a pedido do titular.
      // Exigir consentimento a quem acabou de telefonar seria teatro.
      final chamada = LeadEntrada.fromJson(
        linha(origem: 'telefone', baseLegal: 'diligencia_pre_contratual'),
      );

      expect(chamada.temBaseLegal, isTrue);
      expect(chamada.aceite, isTrue);
    });

    test('uma coluna em falta cai do lado seguro', () {
      // Um servidor antigo, ou uma linha anterior à migração, não devolve a
      // coluna. O erro caro é o contrário do que parece: tratar por consentida
      // uma lead que não é sai muito mais caro do que reter uma que era.
      final antiga = LeadEntrada.fromJson(linha(baseLegal: null));

      expect(antiga.baseLegal, 'nao_registada');
      expect(antiga.aceite, isFalse);
    });

    test('retida sem base legal continua retida — não se soma duas vezes', () {
      expect(
        LeadEntrada.fromJson(
          linha(classificacao: 'retida', baseLegal: 'nao_registada'),
        ).aceite,
        isFalse,
      );
    });
  });

  group('tarefa de triagem', () {
    final agora = DateTime(2026, 7, 15);
    const vazio = OperationsState(onboarded: true);

    test('sem leads retidas não há tarefa', () {
      final tarefas = tarefasPendentes(vazio, agora);

      expect(tarefas.where((t) => t.id == 'leads-retidas'), isEmpty);
    });

    test('leads retidas geram tarefa urgente à frente das outras', () {
      // Uma lead parada é procura já paga que ainda não foi trabalhada.
      final tarefas = tarefasPendentes(vazio, agora, leadsRetidas: 3);

      final tarefa = tarefas.firstWhere((t) => t.id == 'leads-retidas');
      expect(tarefa.titulo, '3 leads à espera de triagem');
      expect(tarefa.severidade, SeveridadeTarefa.urgente);
    });

    test('o singular muda com a contagem', () {
      final tarefas = tarefasPendentes(vazio, agora, leadsRetidas: 1);

      expect(
        tarefas.firstWhere((t) => t.id == 'leads-retidas').titulo,
        '1 lead à espera de triagem',
      );
    });
  });
}
