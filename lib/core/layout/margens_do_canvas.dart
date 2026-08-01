/// As margens do conteúdo dentro do canvas — os números que se mudam a pedido.
///
/// O canvas é a área branca à direita da barra lateral, abaixo da faixa das
/// notificações. As margens do sistema já foram gastas pela moldura da shell;
/// isto é só o ar entre a aresta dessa área e o que lá está dentro.
///
/// Cada número tem nome porque é assim que se pede a mudança: "o vertical passa
/// de 12 para 14", "os menus com botão no topo passam de 3,5 para 4,5". Muda-se
/// aqui e muda em todos os ecrãs de uma vez.
///
/// Antes disto eram sete valores para a mesma distância, um por ficheiro — 12
/// no painel, 18 nas Reservas, 20 nas Tarefas, 24 nos Clientes e Colaboradores,
/// 25 nas Máquinas, 3,5 na Empresa. Ao mudar de menu o conteúdo saltava de
/// sítio, e não havia um sítio onde corrigir isso.
class MargensDoCanvas {
  const MargensDoCanvas._();

  /// Distância aos lados, igual à esquerda e à direita.
  ///
  /// É o que se vê, não o que se escreve: quem tiver ar próprio desconta-o
  /// deste número, para o resultado ao olho ser sempre este. Ver
  /// [lateralNoCarrossel].
  ///
  /// Igual dos dois lados de propósito. Houve uma altura em que a esquerda era
  /// menor, com o argumento de que a barra lateral navy já separa por si — ao
  /// olho lia-se como desalinhamento.
  static const lateral = 15.0;

  /// O ar que a seta do carrossel põe por dentro, entre a margem e o glifo.
  static const arDaSeta = 8.0;

  /// Margem lateral do painel, onde as linhas começam e acabam numa seta.
  ///
  /// Menor do que [lateral] para o resultado ser igual: a seta já traz 8 dp
  /// por dentro, e somar-lhe a margem inteira punha o glifo a 23 dp da aresta
  /// enquanto o texto dos outros menus ficava a 15.
  ///
  /// O desconto é do painel inteiro, mas só a seta o merece — o que lá está e
  /// não é seta (a saudação, os pontinhos do slide) tem de somar [arDaSeta] de
  /// volta, senão fica a 7 da barra enquanto o resto da app está a 15.
  static const lateralNoCarrossel = lateral - arDaSeta;

  /// Distância ao topo e à base, nos ecrãs que começam por conteúdo: texto,
  /// uma lista, os cartões do painel.
  static const vertical = 15.0;

  /// Distância ao topo nos ecrãs que começam por um botão de acção — Máquinas,
  /// Clientes, Reservas — e nos que começam pelos separadores da Empresa.
  ///
  /// É menor do que [vertical] para o resultado ser igual, e não ao contrário:
  /// um botão traz cerca de 14 dp de ar próprio à volta do rótulo, uma linha de
  /// texto não traz nenhum. Somar-lhe a margem inteira contava o mesmo espaço
  /// duas vezes — a primeira letra caía a 24 dp do topo contra 12 no painel.
  static const verticalComBotaoNoTopo = 4.5;
}
