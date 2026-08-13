/// **O painel é do gestor: o que lá está e por que ordem.**
///
/// O painel nasceu com doze células fixas, escritas dentro dos slides. Servia
/// para validar a leitura, mas dizia a todas as empresas a mesma coisa — e a
/// maior parte delas ainda não tem dados para metade daquilo. Quem abria a app
/// via quatro caixas a dizer "aguarda" e concluía, com razão, que a app não
/// sabia nada da vida dele.
///
/// A partir daqui o painel começa **vazio** e enche-se por escolha: na bancada
/// ("KPIs (todos)") marca-se o que sobe e arrasta-se para dar a ordem. Quatro
/// por ecrã, na ordem da lista.
///
/// **Duas listas e não uma.** [ordem] é a arrumação — vale para tudo o que ele
/// tenha arrastado, esteja marcado ou não. [escolhidos] é o que sobe. Guardar
/// só os escolhidos perdia a arrumação de um KPI de cada vez que ele o
/// desmarcasse; guardar só a ordem não distinguia "quero" de "está aqui".
class ArranjoDoPainel {
  const ArranjoDoPainel({this.ordem = const [], this.escolhidos = const {}});

  /// O painel de quem nunca escolheu nada. É o estado inicial, de propósito.
  static const vazio = ArranjoDoPainel();

  /// A arrumação do gestor, por id de KPI. Pode conter ids que ele desmarcou —
  /// e até ids que esta versão da app já não conhece, que se ignoram na leitura
  /// sem se deitarem fora na gravação.
  final List<String> ordem;

  /// Os que sobem ao painel. Invariante: contido em [ordem].
  final Set<String> escolhidos;

  /// Os ids que o painel mostra, pela ordem dele.
  List<String> get noPainel => [
    for (final id in ordem)
      if (escolhidos.contains(id)) id,
  ];

  bool get estaVazio => noPainel.isEmpty;

  bool contem(String id) => escolhidos.contains(id);

  /// Marca ou desmarca um KPI.
  ///
  /// Marcar um que nunca foi arrastado põe-no no fim da arrumação: entrou
  /// agora, vai para o fim da fila. Desmarcar **não** o tira da [ordem] — se
  /// ele voltar, volta ao sítio onde estava.
  ArranjoDoPainel comEscolha(String id, {required bool escolher}) {
    final escolha = {...escolhidos};
    if (escolher) {
      escolha.add(id);
    } else {
      escolha.remove(id);
    }
    return ArranjoDoPainel(
      ordem: ordem.contains(id) ? ordem : [...ordem, id],
      escolhidos: escolha,
    );
  }

  /// Marca [id] e põe-no **logo a seguir** a [depoisDe] na arrumação.
  ///
  /// É o gesto da sugestão do painel: quem sobe é o filho que explica um número
  /// que está mau, e a explicação tem de ficar ao lado do número que explica.
  /// Com o [comEscolha] normal ia para o fim da fila — noutra página do painel,
  /// a quatro células de distância do que o motivou, e o gestor tinha de ir
  /// arrastá-lo até lá para ver os dois juntos.
  ///
  /// Se [depoisDe] não estiver na arrumação, vai para o fim: é o mesmo que
  /// [comEscolha] faria, e não se inventa um lugar a partir de uma âncora que
  /// não existe.
  ArranjoDoPainel comEscolhaJuntoDe(String id, {required String depoisDe}) {
    // Tira-se primeiro para o caso de já lá estar noutro sítio — senão ficava
    // duas vezes na arrumação, e a segunda mandava na ordem.
    final nova = [
      for (final x in ordem)
        if (x != id) x,
    ];
    final ancora = nova.indexOf(depoisDe);
    if (ancora < 0) {
      nova.add(id);
    } else {
      nova.insert(ancora + 1, id);
    }
    return ArranjoDoPainel(ordem: nova, escolhidos: {...escolhidos, id});
  }

  /// A nova arrumação, tal como a lista ficou depois do arrasto.
  ///
  /// **O que não vem em [nova] fica ancorado a quem tinha à frente.** São KPIs
  /// que hoje não estão prontos — perderam a fonte — e por isso não aparecem na
  /// lista que se arrasta. Empurrá-los para o fim era tão mau como deitá-los
  /// fora: no dia 1 do mês, sem movimentos ainda, meio catálogo cai de uma vez;
  /// bastava ele arrastar **um** KPI para a Caixa saltar do segundo cartão para
  /// a última página, sem lhe ter tocado e sem erro nenhum.
  ///
  /// Cada ausente fica atrás do vizinho que já tinha antes na [ordem] — o mesmo
  /// sítio relativo de onde ele o deixou. Quem não tem vizinho anterior fica à
  /// cabeça, que é onde estava.
  ArranjoDoPainel comOrdem(Iterable<String> nova) {
    final arrumados = nova.toList();
    final vistos = arrumados.toSet();

    // Para cada ausente, quem vinha antes dele na arrumação anterior — e que
    // ainda esteja na lista nova, senão a âncora afunda com ele.
    final aReboque = <String?, List<String>>{};
    String? anterior;
    for (final id in ordem) {
      if (vistos.contains(id)) {
        anterior = id;
      } else {
        (aReboque[anterior] ??= []).add(id);
      }
    }

    return ArranjoDoPainel(
      ordem: [
        ...?aReboque[null],
        for (final id in arrumados) ...[id, ...?aReboque[id]],
      ],
      escolhidos: escolhidos,
    );
  }

  /// Arruma [ids] pela ordem do gestor. O que ele nunca arrastou fica no fim,
  /// pela ordem com que veio — que é a do catálogo.
  List<String> arrumar(Iterable<String> ids) {
    final porArrumar = ids.toList();
    final conhecidos = porArrumar.toSet();
    return [
      for (final id in ordem)
        if (conhecidos.contains(id)) id,
      for (final id in porArrumar)
        if (!ordem.contains(id)) id,
    ];
  }

  Map<String, Object?> toJson() => {
    'ordem': ordem,
    'escolhidos': escolhidos.toList(),
  };

  /// Lê o que estava gravado. Repõe a invariante — um escolhido que não conste
  /// da arrumação entra no fim dela — porque uma gravação de uma versão mais
  /// velha (ou meio escrita) não pode deixar um KPI marcado e invisível.
  factory ArranjoDoPainel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return vazio;
    final ordem = _listaDeTexto(json['ordem']);
    final escolhidos = _listaDeTexto(json['escolhidos']).toSet();
    return ArranjoDoPainel(
      ordem: [
        ...ordem,
        for (final id in escolhidos)
          if (!ordem.contains(id)) id,
      ],
      escolhidos: escolhidos,
    );
  }

  static List<String> _listaDeTexto(Object? valor) => valor is List
      ? [
          for (final item in valor)
            if (item is String && item.isNotEmpty) item,
        ]
      : const [];

  @override
  bool operator ==(Object other) =>
      other is ArranjoDoPainel &&
      _mesmaLista(other.ordem, ordem) &&
      other.escolhidos.length == escolhidos.length &&
      other.escolhidos.containsAll(escolhidos);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(ordem), Object.hashAllUnordered(escolhidos));

  static bool _mesmaLista(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
