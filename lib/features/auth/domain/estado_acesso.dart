/// Estado de acesso de uma conta autenticada, tal como o servidor o vê.
///
/// [membroAtivo] vem de `punho_membros.ativo` e [estado] de
/// `punho_pedidos_acesso.estado`. São coisas diferentes de propósito: o pedido
/// pode estar `aprovado` no Control e a adesão ainda não ter sido criada.
class EstadoAcesso {
  final bool membroAtivo;
  final String? perfil;

  /// O estado do pedido, ou `null` quando **não há pedido nenhum**.
  ///
  /// A diferença custou uma tarde a 5 de Agosto de 2026. `punho_meu_acesso`
  /// devolvia `coalesce(..., 'pendente')`: quem nunca tinha pedido nada era
  /// dado como pendente, a app dizia "Pedido em análise" e o Control não tinha
  /// linha nenhuma para aprovar. Ninguém dos dois lados sabia. Ausência de
  /// pedido não é pedido à espera — e é por isto que este campo é nulável.
  final String? estado;

  /// A empresa a que a conta pertence.
  ///
  /// É a chave da sincronização: as operações são por empresa, e sem ela não há
  /// onde as ler nem escrever. Vem da mesma função que já diz se a adesão está
  /// activa, para não haver duas versões da regra de quem é membro.
  ///
  /// `null` em servidores anteriores a esta coluna, e em quem ainda não tem
  /// adesão. Nesse caso não se sincroniza — não se adivinha.
  final String? empresaId;

  /// O nome que a pessoa escreveu no pedido de acesso, e o nome da empresa que
  /// a aprovação criou.
  ///
  /// Existem para o onboarding **não perguntar o que já foi respondido**. A 5
  /// de Agosto de 2026 o César foi aprovado como Alfredo/DepilConcept e a app
  /// abriu-lhe «Como te chamas?» à mesma: os dados estavam no servidor e a app
  /// não tinha por onde os ver.
  ///
  /// Preenchem os campos; não saltam passos. A ficha da empresa continua por
  /// fazer, e dar o onboarding por concluído com um nome e mais nada seria
  /// marcar como feito o que não foi.
  ///
  /// Nulos em servidores anteriores a estas colunas, e enquanto não houver
  /// pedido nem adesão — nesse caso pergunta-se, como sempre.
  final String? nome, empresaNome;

  const EstadoAcesso({
    required this.membroAtivo,
    this.estado,
    this.perfil,
    this.empresaId,
    this.nome,
    this.empresaNome,
  });

  factory EstadoAcesso.fromJson(Map<String, dynamic> json) => EstadoAcesso(
    membroAtivo: json['membro_ativo'] == true,
    perfil: json['perfil'] as String?,
    // Sem `?? 'pendente'`: era esse valor por omissão que apagava a diferença
    // entre "não pediu" e "está à espera". Ver [estado].
    estado: json['estado'] as String?,
    empresaId: json['empresa_id'] as String?,
    nome: _texto(json['nome']),
    empresaNome: _texto(json['empresa_nome']),
  );

  /// Texto que só conta se disser alguma coisa: `''` e espaços valem `null`,
  /// senão o campo aparecia "preenchido" com nada lá dentro.
  static String? _texto(Object? v) {
    if (v is! String) return null;
    final limpo = v.trim();
    return limpo.isEmpty ? null : limpo;
  }

  bool get eGestor => perfil == 'gestor';
}

/// Para onde mandar a conta depois de autenticada.
enum DecisaoAcesso {
  /// Adesão activa: abre a app.
  app,

  /// Ainda sem adesão e sem decisão contrária: "Pedido em análise".
  pendente,

  /// Conta sem adesão e **sem pedido nenhum**: há que o fazer.
  ///
  /// Acontece a quem perde a adesão depois de a ter tido — revogado, ou a
  /// empresa apagada. O pedido só nascia no registo, portanto estas contas
  /// ficavam a olhar para "Pedido em análise" para sempre.
  semPedido,

  /// Recusado ou revogado: "Acesso indisponível".
  indisponivel,
}

/// Regra de entrada, isolada da UI e sem I/O para poder ser testada.
///
/// A adesão activa manda sempre: as contas criadas antes deste modelo não têm
/// pedido nenhum e não podem ficar trancadas de fora por causa disso. Um pedido
/// `aprovado` sem adesão ainda não abre a app — quem cria a linha em
/// `punho_membros` é o Control, e é essa a única prova de acesso.
DecisaoAcesso decidirAcesso(EstadoAcesso acesso) {
  if (acesso.membroAtivo) return DecisaoAcesso.app;
  switch (acesso.estado) {
    case null:
      return DecisaoAcesso.semPedido;
    case 'recusado':
    case 'revogado':
      return DecisaoAcesso.indisponivel;
    default:
      return DecisaoAcesso.pendente;
  }
}
