/// **O ecrã de atenção** — quando um número está mau, dizer qual é o culpado.
///
/// É a Fase 5 do plano de KPIs, e a razão de existir da cadeia. Um painel que
/// pinta o Lucro de vermelho já toda a gente tem. O que o gestor precisa é da
/// frase seguinte: *«o lucro caiu, as vendas mantiveram-se, o que subiu foi a
/// estrutura»* — e é essa que a app tem de saber escrever sozinha.
///
/// ## A conta não é um palpite
///
/// O lucro decompõe-se exactamente:
///
/// ```
///   Lucro    = Vendas − Estrutura − Custos directos
///   ΔLucro   = ΔVendas − ΔEstrutura − ΔCustos directos
/// ```
///
/// Não há heurística nenhuma nem peso arbitrário: a variação de cada parcela
/// **soma** à variação do lucro, ao cêntimo. Ordena-se por quem mexeu mais e o
/// primeiro da lista é o responsável. Se a conta não fechar, é bug — e o teste
/// verifica que fecha.
///
/// ## Contra o quê se compara
///
/// O homólogo primeiro, o mês anterior só quando não há ano passado. Num
/// negócio com estações, comparar Setembro com Agosto acusa o calendário em vez
/// do negócio.
library;

import '../../domain/models/finance.dart';
import '../../domain/models/operations.dart';
import '../operations/kpis_da_cadeia.dart';
import '../operations/kpis_de_saude.dart' show custosDirectosDoAluguer;
import '../operations/operations_controller.dart';

/// Uma parcela do lucro e quanto pesou na variação dele.
class Parcela {
  const Parcela({
    required this.kpiId,
    required this.nome,
    required this.efeitoCents,
    required this.deCents,
    required this.paraCents,
    required this.plural,
  });

  /// O KPI a que esta parcela corresponde, para o ecrã poder navegar até lá.
  /// `null` nas parcelas que ainda não têm KPI próprio.
  final String? kpiId;

  final String nome;

  /// O [nome] é plural («as vendas») ou singular («a estrutura»).
  ///
  /// A concordância do verbo segue o nome, não a contagem da lista: com uma
  /// parcela só, «as vendas manteve-se» é o que sai de contar itens em vez de
  /// olhar para o sujeito. Um erro destes num ecrã que se lê todos os dias
  /// desgasta a confiança em tudo o resto que lá está escrito.
  final bool plural;

  /// Quanto esta parcela empurrou o lucro, **com o sinal do efeito**: uma
  /// estrutura que sobe 900 € entra como −900, porque foi isso que fez ao
  /// lucro. Assim a soma dos efeitos é a variação do lucro, sem sinais a
  /// inverterem-se pelo caminho.
  final int efeitoCents;

  final int deCents, paraCents;

  /// Quanto a própria parcela variou, sem orientação — para o texto.
  int get variacaoCents => paraCents - deCents;

  bool get ajudou => efeitoCents > 0;
}

/// Porque é que o lucro deste mês é o que é.
class AtencaoDoLucro {
  const AtencaoDoLucro({
    required this.lucroCents,
    required this.lucroDeReferenciaCents,
    required this.homologo,
    required this.parcelas,
  });

  final int lucroCents;
  final int lucroDeReferenciaCents;

  /// A referência é o mesmo mês do ano passado (`true`) ou o mês anterior.
  final bool homologo;

  /// Todas as parcelas, da que mais pesou para a que menos pesou — em valor
  /// absoluto, porque uma que ajudou muito também explica.
  final List<Parcela> parcelas;

  int get variacaoCents => lucroCents - lucroDeReferenciaCents;

  bool get piorou => variacaoCents < 0;

  /// A parcela que mais pesou. É o «culpado» quando o lucro piorou, e o herói
  /// quando melhorou.
  Parcela get responsavel => parcelas.first;

  /// As parcelas que empurraram para o mesmo lado que o lucro.
  List<Parcela> get noMesmoSentido =>
      parcelas.where((p) => p.ajudou != piorou).toList();

  /// As que empurraram ao contrário — as que seguraram a queda, ou as que
  /// travaram a subida. Dizê-las evita a leitura injusta: um mês em que a
  /// estrutura disparou e as vendas também subiram não é um mês de vendas más.
  List<Parcela> get contraCorrente =>
      parcelas.where((p) => p.ajudou == piorou).toList();
}

String _euros(int cents) => '${(cents / 100).round()} €';

/// Uma parcela «manteve-se» quando mexeu menos de 5% — abaixo disso a
/// diferença não muda decisão nenhuma e escrevê-la como causa é ruído.
const _bandaDeManteveSe = 0.05;

bool _manteveSe(Parcela p) =>
    p.deCents != 0 && (p.variacaoCents / p.deCents).abs() < _bandaDeManteveSe;

/// A frase que o gestor lê. Em português, na segunda pessoa, e sempre com o
/// número ao lado da afirmação — «subiu» sem quanto não se pode verificar.
String fraseDaAtencao(AtencaoDoLucro a) {
  // «face a o mês passado» — a contracção escreve-se aqui e não no termo, para
  // o termo poder ser usado sozinho noutro sítio.
  final termo = a.homologo ? 'ao mesmo mês do ano passado' : 'ao mês passado';
  final verbo = a.piorou ? 'caiu' : 'subiu';
  final abertura =
      'O lucro $verbo ${_euros(a.variacaoCents.abs())} face $termo.';

  final culpado = a.responsavel;
  final movimento = culpado.variacaoCents >= 0 ? 'subiu' : 'desceu';
  final causa =
      'O que ${movimento == 'subiu' ? 'mais subiu' : 'mais desceu'} '
      'foi ${culpado.nome}: ${_euros(culpado.variacaoCents.abs())} '
      '(${_euros(culpado.deCents)} → ${_euros(culpado.paraCents)}).';

  // A parcela que se manteve é metade da notícia: sem ela, «a estrutura subiu»
  // lê-se como se as vendas também tivessem corrido mal.
  final estaveis = a.parcelas.where(_manteveSe).toList();
  // Duas parcelas juntas dão sempre plural; uma só concorda com o próprio nome.
  final verbo2 =
      estaveis.length > 1 || (estaveis.length == 1 && estaveis.single.plural)
      ? 'mantiveram-se'
      : 'manteve-se';
  final estabilidade = estaveis.isEmpty
      ? ''
      : ' Já ${_lista([for (final p in estaveis) p.nome])} $verbo2.';

  return '$abertura $causa$estabilidade';
}

String _lista(List<String> nomes) {
  if (nomes.length == 1) return nomes.single;
  return '${nomes.sublist(0, nomes.length - 1).join(', ')} e ${nomes.last}';
}

DateTime _inicioDoMes(DateTime d) => DateTime(d.year, d.month);
DateTime _fimDoMes(DateTime d) => DateTime(d.year, d.month + 1, 0);

Iterable<Expense> _despesas(OperationsState s, DateTime mes) =>
    s.expenses.where(
      (e) =>
          !e.archived && isInPeriod(e.date, _inicioDoMes(mes), _fimDoMes(mes)),
    );

int _estrutura(OperationsState s, DateTime mes) => _despesas(s, mes)
    .where((e) => !custosDirectosDoAluguer.contains(e.category))
    .fold(0, (t, e) => t + e.amountCents);

int _directos(OperationsState s, DateTime mes) => _despesas(s, mes)
    .where((e) => custosDirectosDoAluguer.contains(e.category))
    .fold(0, (t, e) => t + e.amountCents);

int _vendas(OperationsState s, DateTime mes) => s.bookings
    .where(
      (b) =>
          b.status != BookingStatus.cancelled &&
          (b.expectedValueCents ?? 0) > 0 &&
          isInPeriod(b.endsAt, _inicioDoMes(mes), _fimDoMes(mes)),
    )
    .fold(0, (t, b) => t + b.expectedValueCents!);

/// Decompõe a variação do lucro nas parcelas que a causaram.
///
/// `null` quando não há mês de referência com que comparar — e aí não se diz
/// nada, em vez de se inventar uma explicação para uma variação que não existe.
AtencaoDoLucro? atencaoDoLucro(OperationsState s, DateTime now) {
  final lucro = lucroDoMes(s, now);
  if (lucro == null) return null;

  final homologo = lucro.homologoCents != null;
  final referenciaCents = lucro.homologoCents ?? lucro.mesAnteriorCents;
  if (referenciaCents == null) return null;

  final mesRef = homologo
      ? DateTime(now.year - 1, now.month)
      : DateTime(now.year, now.month - 1);

  final parcelas = [
    Parcela(
      kpiId: 'vendas-mes',
      nome: 'as vendas',
      plural: true,
      deCents: _vendas(s, mesRef),
      paraCents: _vendas(s, now),
      // Vendas a subir empurram o lucro para cima: efeito com o mesmo sinal.
      efeitoCents: _vendas(s, now) - _vendas(s, mesRef),
    ),
    Parcela(
      kpiId: 'estrutura-mes',
      nome: 'a estrutura',
      plural: false,
      deCents: _estrutura(s, mesRef),
      paraCents: _estrutura(s, now),
      // Custos a subir empurram o lucro para baixo: efeito com o sinal trocado.
      efeitoCents: _estrutura(s, mesRef) - _estrutura(s, now),
    ),
    Parcela(
      kpiId: null,
      nome: 'o custo de servir os trabalhos',
      plural: false,
      deCents: _directos(s, mesRef),
      paraCents: _directos(s, now),
      efeitoCents: _directos(s, mesRef) - _directos(s, now),
    ),
  ]..sort((a, b) => b.efeitoCents.abs().compareTo(a.efeitoCents.abs()));

  return AtencaoDoLucro(
    lucroCents: lucro.valorCents,
    lucroDeReferenciaCents: referenciaCents,
    homologo: homologo,
    parcelas: parcelas,
  );
}
