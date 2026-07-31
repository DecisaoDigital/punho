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
  }) => {
    'id': 'e1',
    'origem': origem,
    'classificacao': classificacao,
    'recebida_em': '2026-07-10T09:00:00.000Z',
    'nome': nome,
    'telefone_e164': telefone,
    'mensagem': mensagem,
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
