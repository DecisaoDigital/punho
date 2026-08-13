/// **Quem devia subir ao painel — proposto, nunca imposto.**
///
/// Era a última peça do plano de KPIs por construir (Fase 8, «promoção
/// automática»), e a palavra *automática* é a parte que não se fez: o painel é
/// do gestor, e uma app que lhe muda as quatro células enquanto ele não olha
/// tira-lhe exactamente aquilo que a bancada lhe deu. O que aqui se calcula é
/// **uma frase e um botão** — a app diz quem sobe e porquê, ele carrega ou
/// ignora.
///
/// ## A regra
///
/// Sugere-se o **filho que explica um número que está mau e já está no painel**.
/// É a razão de existir da cadeia, aplicada ao sítio onde ela vale mais: de nada
/// serve o Lucro ter filhos se o gestor tiver de ir à bancada descobrir qual
/// deles olhar.
///
/// Três condições, e todas contam:
///
/// 1. **O pai está no painel e está mau.** Um KPI que ele não escolheu ver não
///    autoriza a app a propor-lhe mais nada; e um número que está bem não
///    precisa de explicação.
/// 2. **O filho está pronto** — fonte cheia e conta verificada. É a mesma regra
///    que a bancada aplica às caixas de marcar: não se promove o que nós
///    próprios ainda não assinámos.
/// 3. **O filho está mau também.** Sem isto, um Lucro em baixo propunha as
///    Vendas que estão óptimas, e a sugestão passava a ruído. Quando nenhum
///    filho está mau, não se diz nada — silêncio é uma resposta legítima.
///
/// ## Qual dos filhos
///
/// No Lucro do mês não se adivinha: a decomposição de `atencao.dart` já sabe
/// qual das parcelas mexeu mais, ao cêntimo, e é essa que sobe. Nos outros, o
/// que estiver pior; empatados, o primeiro do catálogo.
///
/// ## Uma de cada vez
///
/// Devolve-se **uma** sugestão, não uma lista. Duas sugestões já são um painel
/// a ser escolhido por outra pessoa, e a segunda deixa de se ler.
library;

import '../../../core/kpis/atencao.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../domain/models/arranjo_do_painel.dart';
import '../../dashboard/presentation/kpi_catalogo.dart';
import '../../dashboard/presentation/widgets/celula_semaforo.dart';

/// O KPI que a app propõe pôr no painel, e a frase que o justifica.
class SugestaoDoPainel {
  const SugestaoDoPainel({
    required this.kpi,
    required this.pai,
    required this.motivo,
  });

  /// Quem sobe.
  final KpiDefinicao kpi;

  /// O número que está mau e que este ajuda a explicar. Já está no painel — é
  /// dele que a sugestão nasce, e é ao lado dele que o filho vai ficar.
  final KpiDefinicao pai;

  /// Porquê, em português e com o número lá dentro. «O lucro caiu 683 €» é
  /// verificável; «o lucro caiu» é uma opinião.
  final String motivo;
}

/// Níveis que fazem um KPI valer uma explicação.
///
/// `aguarda` fica de fora e é a decisão que importa: um KPI à espera de dados
/// não está mau, está por começar — propor-lhe um filho era responder a uma
/// pergunta que ninguém fez.
const _maus = {NivelSemaforo.vermelho, NivelSemaforo.laranja};

/// O que a app propõe pôr no painel agora, ou `null` se não tiver nada a dizer.
SugestaoDoPainel? sugestaoDoPainel(
  OperationsState estado,
  ArranjoDoPainel arranjo,
  DateTime now,
) {
  // Pela ordem do painel: o primeiro número mau que ele vê é o primeiro que
  // merece explicação.
  for (final pai in kpisEscolhidos(arranjo)) {
    if (!_maus.contains(pai.celula(estado, now).nivel)) continue;

    final candidatos = [
      for (final filho in filhosDe(pai.id))
        if (!arranjo.contem(filho.id) &&
            filho.estado(estado, now) == EstadoVerdade.pronto)
          filho,
    ];
    if (candidatos.isEmpty) continue;

    final sugestao =
        _peloQueMaisPesou(pai, candidatos, estado, now) ??
        _peloPiorFilho(pai, candidatos, estado, now);
    if (sugestao != null) return sugestao;
  }
  return null;
}

/// A sugestão que a decomposição do lucro aponta — a única que não é um palpite.
///
/// `ΔLucro = ΔVendas − ΔEstrutura − ΔCustos directos`, e a parcela que mais
/// pesou é conhecida ao cêntimo. Aqui não se olha para o nível do filho: se foi
/// a estrutura que comeu o lucro, é a estrutura que sobe, esteja a célula dela
/// laranja ou verde. **É a conta que manda, não a cor.**
SugestaoDoPainel? _peloQueMaisPesou(
  KpiDefinicao pai,
  List<KpiDefinicao> candidatos,
  OperationsState estado,
  DateTime now,
) {
  if (pai.id != 'lucro-mes') return null;
  final atencao = atencaoDoLucro(estado, now);
  if (atencao == null || !atencao.piorou) return null;

  final responsavel = atencao.responsavel;
  for (final filho in candidatos) {
    if (filho.id != responsavel.kpiId) continue;
    return SugestaoDoPainel(
      kpi: filho,
      pai: pai,
      // «o que mais pesou foi as vendas» é o que sai de escrever a frase sem
      // olhar para o sujeito. A concordância segue o nome da parcela, que já
      // sabe se é plural — a mesma regra do ecrã de atenção.
      motivo:
          'O lucro caiu ${_euros(atencao.variacaoCents.abs())} e o que mais '
          'pesou ${responsavel.plural ? 'foram' : 'foi'} ${responsavel.nome}.',
    );
  }
  return null;
}

/// Fora do lucro não há decomposição exacta, e por isso exige-se mais: só se
/// propõe um filho que esteja ele próprio mau. Um pai laranja com todos os
/// filhos verdes não gera sugestão nenhuma — o que há a dizer sobre ele já está
/// dito na célula.
SugestaoDoPainel? _peloPiorFilho(
  KpiDefinicao pai,
  List<KpiDefinicao> candidatos,
  OperationsState estado,
  DateTime now,
) {
  KpiDefinicao? pior;
  var gravidade = 0;
  for (final filho in candidatos) {
    // Primeiro a ganhar fica: empatados, manda a ordem do catálogo. Um `sort`
    // não servia — o do Dart não promete ser estável, e a sugestão passaria a
    // mudar de KPI sem nada ter mudado no negócio.
    final peso = _gravidade(filho.celula(estado, now).nivel);
    if (peso > gravidade) {
      gravidade = peso;
      pior = filho;
    }
  }
  if (pior == null) return null;

  return SugestaoDoPainel(
    kpi: pior,
    pai: pai,
    motivo:
        '${pai.titulo} está em alerta, e ${pior.titulo} também — '
        'é aí que se vê porquê.',
  );
}

int _gravidade(NivelSemaforo nivel) => switch (nivel) {
  NivelSemaforo.vermelho => 2,
  NivelSemaforo.laranja => 1,
  NivelSemaforo.verde || NivelSemaforo.aguarda => 0,
};

String _euros(int cents) => '${(cents / 100).round()} €';
