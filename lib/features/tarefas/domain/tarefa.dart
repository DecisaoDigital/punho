/// O que a app pede ao gestor para fazer.
///
/// Existia disperso: um alerta condicional no fundo do painel para dados por
/// completar, outro para máquinas por identificar, outro para colaboradores
/// incompletos. Quem não descia o painel até ao fim nunca os via. Agora é uma
/// lista só, com contagem na barra lateral.
enum SeveridadeTarefa {
  /// Dinheiro ou obrigações legais. Não espera.
  urgente('Urgente', 2),

  /// Falta preencher algo que faz o Punho decidir melhor.
  aCompletar('A completar', 1),

  /// Conselho que o gestor adiou. Fica à mão, sem incomodar.
  sugestao('Sugestão', 0);

  const SeveridadeTarefa(this.label, this.prioridade);
  final String label;
  final int prioridade;
}

/// Para onde a CTA da tarefa leva. A página resolve isto em navegação — o
/// serviço não conhece widgets.
enum DestinoTarefa {
  definicoesEmpresa,
  clientes,
  maquinas,
  colaboradores,
  frota,
  reservas,
  financas,
  convites,
  painel,
}

class Tarefa {
  const Tarefa({
    required this.id,
    required this.severidade,
    required this.titulo,
    required this.subtitulo,
    required this.cta,
    required this.destino,
  });

  final String id;
  final SeveridadeTarefa severidade;
  final String titulo;
  final String subtitulo;

  /// Texto do botão, já com o verbo ("Preencher NIF", "Cobrar João Silva").
  final String cta;
  final DestinoTarefa destino;
}
