/// Estado de acesso de uma conta autenticada, tal como o servidor o vê.
///
/// [membroAtivo] vem de `punho_membros.ativo` e [estado] de
/// `punho_pedidos_acesso.estado`. São coisas diferentes de propósito: o pedido
/// pode estar `aprovado` no Control e a adesão ainda não ter sido criada.
class EstadoAcesso {
  final bool membroAtivo;
  final String? perfil;
  final String estado;

  /// A empresa a que a conta pertence.
  ///
  /// É a chave da sincronização: as operações são por empresa, e sem ela não há
  /// onde as ler nem escrever. Vem da mesma função que já diz se a adesão está
  /// activa, para não haver duas versões da regra de quem é membro.
  ///
  /// `null` em servidores anteriores a esta coluna, e em quem ainda não tem
  /// adesão. Nesse caso não se sincroniza — não se adivinha.
  final String? empresaId;

  const EstadoAcesso({
    required this.membroAtivo,
    required this.estado,
    this.perfil,
    this.empresaId,
  });

  factory EstadoAcesso.fromJson(Map<String, dynamic> json) => EstadoAcesso(
    membroAtivo: json['membro_ativo'] == true,
    perfil: json['perfil'] as String?,
    estado: (json['estado'] as String?) ?? 'pendente',
    empresaId: json['empresa_id'] as String?,
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
