/// Estado de acesso de uma conta autenticada, tal como o servidor o vê.
///
/// [membroAtivo] vem de `punho_membros.ativo` e [estado] de
/// `punho_pedidos_acesso.estado`. São coisas diferentes de propósito: o pedido
/// pode estar `aprovado` no Control e a adesão ainda não ter sido criada.
class EstadoAcesso {
  final bool membroAtivo;
  final String? perfil;
  final String estado;

  const EstadoAcesso({
    required this.membroAtivo,
    required this.estado,
    this.perfil,
  });

  factory EstadoAcesso.fromJson(Map<String, dynamic> json) => EstadoAcesso(
    membroAtivo: json['membro_ativo'] == true,
    perfil: json['perfil'] as String?,
    estado: (json['estado'] as String?) ?? 'pendente',
  );

  bool get eGestor => perfil == 'gestor';
}

/// Para onde mandar a conta depois de autenticada.
enum DecisaoAcesso {
  /// Adesão activa: abre a app.
  app,

  /// Ainda sem adesão e sem decisão contrária: "Pedido em análise".
  pendente,

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
    case 'recusado':
    case 'revogado':
      return DecisaoAcesso.indisponivel;
    default:
      return DecisaoAcesso.pendente;
  }
}
