import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/campos.dart';
import '../contabilista_providers.dart';
import '../domain/contabilista.dart';

/// Uma rubrica, mês a mês, agrupada por ano.
///
/// É a mesma grelha que o contabilista vê no portal, com as mesmas regras — e
/// tem de ser, porque escrevem os dois na mesma tabela:
///
///  * **Em branco não é zero.** Apagar o campo apaga a resposta e devolve-a a
///    "não sei". Zero é uma resposta: quer dizer que nesse mês não houve nada.
///  * **O total do ano é uma linha à parte**, não doze médias. A média entra na
///    leitura, marcada como repartida, e o mês verdadeiro ganha-lhe sempre.
///  * **O valor volta formatado** depois de gravar, para se ver como ficou
///    interpretado. `1.200` são mil e duzentos euros aqui, como no portal.
class RubricaMesesPage extends ConsumerStatefulWidget {
  const RubricaMesesPage({super.key, required this.rubrica});

  final RubricaContabilista rubrica;

  @override
  ConsumerState<RubricaMesesPage> createState() => _RubricaMesesPageState();
}

class _RubricaMesesPageState extends ConsumerState<RubricaMesesPage> {
  @override
  Widget build(BuildContext context) {
    final respostas = ref.watch(respostasDaRubricaProvider(widget.rubrica.chave));
    return Scaffold(
      appBar: AppBar(title: Text(widget.rubrica.rotulo)),
      body: respostas.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (erro, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Não foi possível ler as respostas.\n$erro',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (guardadas) => _Grelha(
          rubrica: widget.rubrica,
          guardadas: guardadas,
        ),
      ),
    );
  }
}

class _Grelha extends ConsumerStatefulWidget {
  const _Grelha({required this.rubrica, required this.guardadas});

  final RubricaContabilista rubrica;
  final List<RespostaContabilista> guardadas;

  @override
  ConsumerState<_Grelha> createState() => _GrelhaState();
}

class _GrelhaState extends ConsumerState<_Grelha> {
  /// Chave -> valor guardado. `'2025-03'` para um mês, `'a2025'` para o total
  /// de um ano, `'u'` para uma rubrica de resposta única.
  late Map<String, RespostaContabilista> _porChave;

  /// Campos com gravação em curso, para não deixar carregar duas vezes.
  final _aGravar = <String>{};

  @override
  void initState() {
    super.initState();
    _indexar();
  }

  @override
  void didUpdateWidget(covariant _Grelha anterior) {
    super.didUpdateWidget(anterior);
    if (!identical(anterior.guardadas, widget.guardadas)) _indexar();
  }

  void _indexar() {
    _porChave = {
      for (final r in widget.guardadas) _chaveDe(mes: r.mes, ano: r.ano): r,
    };
  }

  static String _chaveDe({DateTime? mes, int? ano}) {
    if (mes != null) {
      return '${mes.year}-${mes.month.toString().padLeft(2, '0')}';
    }
    if (ano != null) return 'a$ano';
    return 'u';
  }

  /// Grava um campo e devolve o valor como o servidor ficou a saber dele.
  ///
  /// Devolver o valor interpretado — em vez de confiar no que se escreveu — é o
  /// que impede alguém de escrever `1.200` a pensar em mil e duzentos euros e
  /// ficar com um euro e vinte sem dar por isso.
  Future<String?> _gravar({
    DateTime? mes,
    int? ano,
    required String texto,
  }) async {
    final chave = _chaveDe(mes: mes, ano: ano);
    if (_aGravar.contains(chave)) return null;

    final int? centavos;
    final String? valorTexto;
    if (widget.rubrica.eEuros) {
      centavos = centsDeTexto(texto, permitirNegativo: true);
      valorTexto = null;
      if (centavos == null && texto.trim().isNotEmpty) {
        _avisar('Não percebi esse número.');
        return null;
      }
    } else {
      centavos = null;
      valorTexto = texto.trim().isEmpty ? null : texto.trim();
    }

    setState(() => _aGravar.add(chave));
    try {
      await ref
          .read(contabilistaServiceProvider)
          .guardar(
            rubrica: widget.rubrica.chave,
            mes: mes,
            ano: ano,
            valorCentavos: centavos,
            valorTexto: valorTexto,
          );
      // As lacunas mudaram, e com elas as Tarefas. Sem isto o gestor preenchia
      // tudo e continuava a ver "faltam 42 meses" até reiniciar.
      ref.invalidate(lacunasContabilistaProvider);
      return widget.rubrica.eEuros ? textoDeCents(centavos) : (valorTexto ?? '');
    } catch (erro) {
      _avisar(_mensagemDeErro(erro));
      return null;
    } finally {
      if (mounted) setState(() => _aGravar.remove(chave));
    }
  }

  void _avisar(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final rubrica = widget.rubrica;

    if (rubrica.periodicidade == PeriodicidadeRubrica.unica) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (rubrica.ajuda != null) ...[
            Text(rubrica.ajuda!, style: textos.bodyMedium),
            const SizedBox(height: 20),
          ],
          _CampoDeResposta(
            rotulo: rubrica.rotulo,
            valorInicial: _textoDe(_porChave['u']),
            opcoes: rubrica.opcoes,
            eEuros: rubrica.eEuros,
            origem: _porChave['u']?.origem,
            aGravar: _aGravar.contains('u'),
            aoConfirmar: (texto) => _gravar(texto: texto),
          ),
        ],
      );
    }

    final anos = _anosAMostrar();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          rubrica.ajuda ??
              'Deixe em branco o que não souber. Em branco não é zero — zero '
                  'quer dizer que nesse mês não houve nada.',
          style: textos.bodyMedium,
        ),
        const SizedBox(height: 20),
        for (final ano in anos)
          _AnoExpansivel(
            ano: ano,
            rubrica: rubrica,
            valorDoMes: (mes) => _porChave[_chaveDe(mes: mes)],
            valorDoAno: _porChave['a$ano'],
            estaAGravar: _aGravar.contains,
            chaveDe: _chaveDe,
            aoGravarMes: (mes, texto) => _gravar(mes: mes, texto: texto),
            aoGravarAno: (texto) => _gravar(ano: ano, texto: texto),
          ),
      ],
    );
  }

  /// Que anos mostrar.
  ///
  /// Do ano em que há resposta mais antiga até ao corrente, e nunca menos do
  /// que os últimos cinco — senão uma empresa sem nada respondido abria um ecrã
  /// vazio e não havia por onde começar.
  List<int> _anosAMostrar() {
    final agora = DateTime.now();
    var maisAntigo = agora.year - 4;
    for (final r in widget.guardadas) {
      final ano = r.mes?.year ?? r.ano;
      if (ano != null && ano < maisAntigo) maisAntigo = ano;
    }
    return [for (var a = agora.year; a >= maisAntigo; a--) a];
  }

  String _textoDe(RespostaContabilista? r) {
    if (r == null) return '';
    return widget.rubrica.eEuros
        ? textoDeCents(r.valorCentavos)
        : (r.valorTexto ?? '');
  }
}

class _AnoExpansivel extends StatelessWidget {
  const _AnoExpansivel({
    required this.ano,
    required this.rubrica,
    required this.valorDoMes,
    required this.valorDoAno,
    required this.estaAGravar,
    required this.chaveDe,
    required this.aoGravarMes,
    required this.aoGravarAno,
  });

  final int ano;
  final RubricaContabilista rubrica;
  final RespostaContabilista? Function(DateTime mes) valorDoMes;
  final RespostaContabilista? valorDoAno;
  final bool Function(String chave) estaAGravar;
  final String Function({DateTime? mes, int? ano}) chaveDe;
  final Future<String?> Function(DateTime mes, String texto) aoGravarMes;
  final Future<String?> Function(String texto) aoGravarAno;

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final ultimoMes = ano == agora.year ? agora.month - 1 : 12;
    final meses = [
      for (var m = 1; m <= ultimoMes; m++) DateTime(ano, m, 1),
    ];
    final preenchidos = meses.where((m) => valorDoMes(m) != null).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        // O ano corrente aberto, os outros fechados: é onde se está a trabalhar.
        initiallyExpanded: ano == agora.year,
        shape: const Border(),
        title: Text('$ano', style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(
          meses.isEmpty
              ? 'Ainda não há meses fechados'
              : '$preenchidos de ${meses.length} '
                    '${meses.length == 1 ? 'mês' : 'meses'} respondidos',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (final mes in meses)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CampoDeResposta(
                rotulo: _mesesLongos[mes.month - 1],
                valorInicial: rubrica.eEuros
                    ? textoDeCents(valorDoMes(mes)?.valorCentavos)
                    : (valorDoMes(mes)?.valorTexto ?? ''),
                opcoes: const [],
                eEuros: rubrica.eEuros,
                origem: valorDoMes(mes)?.origem,
                aGravar: estaAGravar(chaveDe(mes: mes)),
                aoConfirmar: (texto) => aoGravarMes(mes, texto),
              ),
            ),
          if (rubrica.aceitaAnual) ...[
            const Divider(height: 24),
            Text(
              'Não sabe os meses?',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Escreva o total de $ano e o Punho reparte-o pelos meses que '
              'ficarem por preencher. Fica marcado como repartido — um mês '
              'verdadeiro ganha-lhe sempre.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            _CampoDeResposta(
              rotulo: 'Total de $ano',
              valorInicial: textoDeCents(valorDoAno?.valorCentavos),
              opcoes: const [],
              eEuros: true,
              origem: valorDoAno?.origem,
              aGravar: estaAGravar(chaveDe(ano: ano)),
              aoConfirmar: aoGravarAno,
            ),
          ],
        ],
      ),
    );
  }
}

/// Um campo que grava ao sair, e que se reescreve com o que o servidor
/// entendeu.
class _CampoDeResposta extends StatefulWidget {
  const _CampoDeResposta({
    required this.rotulo,
    required this.valorInicial,
    required this.opcoes,
    required this.eEuros,
    required this.origem,
    required this.aGravar,
    required this.aoConfirmar,
  });

  final String rotulo;
  final String valorInicial;
  final List<String> opcoes;
  final bool eEuros;
  final OrigemResposta? origem;
  final bool aGravar;

  /// Devolve o valor como ficou guardado, ou `null` se não gravou.
  final Future<String?> Function(String texto) aoConfirmar;

  @override
  State<_CampoDeResposta> createState() => _CampoDeRespostaState();
}

class _CampoDeRespostaState extends State<_CampoDeResposta> {
  late final TextEditingController _controlo = TextEditingController(
    text: widget.valorInicial,
  );
  late final FocusNode _foco = FocusNode();
  late String _ultimoGravado = widget.valorInicial;

  @override
  void initState() {
    super.initState();
    _foco.addListener(() {
      if (!_foco.hasFocus) _confirmar();
    });
  }

  @override
  void dispose() {
    _controlo.dispose();
    _foco.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (_controlo.text == _ultimoGravado) return;
    final resultado = await widget.aoConfirmar(_controlo.text);
    if (!mounted) return;
    if (resultado == null) {
      // Recusado. Repõe-se o que estava, senão o campo mostra um valor que a
      // base não tem.
      _controlo.text = _ultimoGravado;
      return;
    }
    _ultimoGravado = resultado;
    _controlo.text = resultado;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.opcoes.isNotEmpty) {
      return DropdownButtonFormField<String>(
        initialValue: widget.opcoes.contains(_ultimoGravado)
            ? _ultimoGravado
            : null,
        decoration: InputDecoration(
          labelText: widget.rotulo,
          helperText: _ajudaDaOrigem(widget.origem),
        ),
        items: [
          for (final opcao in widget.opcoes)
            DropdownMenuItem(value: opcao, child: Text(opcao)),
        ],
        onChanged: widget.aGravar
            ? null
            : (valor) async {
                if (valor == null) return;
                final resultado = await widget.aoConfirmar(valor);
                if (resultado != null && mounted) {
                  setState(() => _ultimoGravado = resultado);
                }
              },
      );
    }

    return TextField(
      controller: _controlo,
      focusNode: _foco,
      enabled: !widget.aGravar,
      keyboardType: widget.eEuros
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => _confirmar(),
      decoration: InputDecoration(
        labelText: widget.rotulo,
        isDense: true,
        suffixText: widget.eEuros ? '€' : null,
        helperText: _ajudaDaOrigem(widget.origem),
        suffixIcon: widget.aGravar
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
    );
  }
}

/// Dizer de onde veio o número só quando veio de alguém. Um campo vazio não tem
/// origem, e escrever "—" por baixo de cada mês em branco enchia o ecrã de
/// ruído.
String? _ajudaDaOrigem(OrigemResposta? origem) => origem?.label;

String _mensagemDeErro(Object erro) {
  final texto = erro.toString();
  final marca = texto.indexOf('message: ');
  if (marca >= 0) {
    final resto = texto.substring(marca + 9);
    final fim = resto.indexOf(', code:');
    return fim > 0 ? resto.substring(0, fim) : resto;
  }
  return texto;
}

const _mesesLongos = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];
