import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/auth/domain/estado_acesso.dart';

/// **O onboarding não pergunta o que o servidor já sabe.**
///
/// Quem pede acesso escreve o nome e a empresa no pedido; o Control aprova-os.
/// A 5 de Agosto de 2026 o César foi aprovado como Alfredo / DepilConcept e o
/// Punho abriu-lhe «Como te chamas?» à mesma — os dados estavam no servidor e
/// `punho_meu_acesso` só devolvia o estado, portanto a app não tinha por onde
/// os ver.
///
/// Estes campos **preenchem** os três primeiros passos; não os saltam. A ficha
/// da empresa continua por fazer, e dá-la por concluída com um nome e mais
/// nada seria marcar como feito o que não foi.
void main() {
  EstadoAcesso doServidor(Map<String, dynamic> linha) =>
      EstadoAcesso.fromJson({'membro_ativo': true, ...linha});

  test('traz o nome do pedido e o nome da empresa aprovada', () {
    final a = doServidor({
      'perfil': 'gestor',
      'estado': 'aprovado',
      'nome': 'Alfredo',
      'empresa_nome': 'DepilConcept',
    });

    expect(a.nome, 'Alfredo');
    expect(a.empresaNome, 'DepilConcept');
    expect(a.eGestor, isTrue);
  });

  test('um servidor sem estas colunas não parte nada', () {
    // A app actualiza antes do servidor, e o contrário também acontece.
    final a = doServidor({'perfil': 'gestor', 'estado': 'aprovado'});

    expect(a.nome, isNull);
    expect(a.empresaNome, isNull);
    expect(a.membroAtivo, isTrue);
  });

  test('espaços em branco não contam como preenchidos', () {
    // Um campo "preenchido" com nada lá dentro é pior do que um campo vazio:
    // parece respondido e não é.
    final a = doServidor({'nome': '   ', 'empresa_nome': ''});

    expect(a.nome, isNull);
    expect(a.empresaNome, isNull);
  });

  test('saber o nome não abre a porta por si', () {
    // A prova de acesso continua a ser a adesão activa. Um pedido aprovado sem
    // linha em `punho_membros` não entra, mesmo trazendo nome e empresa.
    final a = EstadoAcesso.fromJson({
      'membro_ativo': false,
      'estado': 'aprovado',
      'nome': 'Alfredo',
      'empresa_nome': 'DepilConcept',
    });

    expect(decidirAcesso(a), DecisaoAcesso.pendente);
  });
}
