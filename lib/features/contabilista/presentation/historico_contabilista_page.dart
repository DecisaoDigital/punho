import 'package:flutter/material.dart';

import '../../../core/layout/ecra_de_formulario.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/operations/operations_controller.dart';
import '../contabilista_providers.dart';
import '../data/contabilista_service.dart';
import '../domain/contabilista.dart';
import 'rubrica_meses_page.dart';

/// O histórico da empresa antes do Punho, e quem o preenche.
///
/// Duas coisas num ecrã porque são a mesma pergunta vista de dois lados: o que
/// falta saber sobre o passado, e quem está a responder a isso. Separá-las dava
/// um ecrã de convites que não dizia para quê e um ecrã de lacunas que não
/// dizia como as resolver.
class HistoricoContabilistaPage extends ConsumerWidget {
  const HistoricoContabilistaPage({super.key, this.abrirRubrica});

  /// Rubrica a abrir logo à entrada. Vem das Tarefas: chegar aqui a partir de
  /// "faltam 42 meses de faturação" e cair numa lista de rubricas obrigava a
  /// procurar outra vez a que se acabou de ler.
  final String? abrirRubrica;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogo = ref.watch(catalogoContabilistaProvider);
    final lacunas = ref.watch(lacunasContabilistaProvider);
    final convites = ref.watch(convitesContabilistaProvider);

    return catalogo.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (erro, _) => _Falha(erro: erro),
      data: (rubricas) {
        final porChave = <String, LacunaContabilista>{
          for (final l in lacunas.valueOrNull ?? const <LacunaContabilista>[])
            l.rubrica: l,
        };
        return _Corpo(
          rubricas: rubricas,
          lacunas: porChave,
          convites: convites.valueOrNull ?? const <ConviteContabilista>[],
          aCarregarConvites: convites.isLoading,
          abrirRubrica: abrirRubrica,
        );
      },
    );
  }
}

class _Corpo extends ConsumerStatefulWidget {
  const _Corpo({
    required this.rubricas,
    required this.lacunas,
    required this.convites,
    required this.aCarregarConvites,
    this.abrirRubrica,
  });

  final List<RubricaContabilista> rubricas;
  final Map<String, LacunaContabilista> lacunas;
  final List<ConviteContabilista> convites;
  final bool aCarregarConvites;
  final String? abrirRubrica;

  @override
  ConsumerState<_Corpo> createState() => _CorpoState();
}

class _CorpoState extends ConsumerState<_Corpo> {
  bool _jaSaltou = false;

  @override
  void initState() {
    super.initState();
    // O salto acontece uma vez e depois de a primeira pintura estar feita, para
    // o ecrã de trás existir quando o utilizador carregar em voltar.
    final rubrica = widget.abrirRubrica;
    if (rubrica == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _jaSaltou) return;
      _jaSaltou = true;
      final alvo = widget.rubricas.where((r) => r.chave == rubrica).firstOrNull;
      if (alvo != null) _abrir(alvo);
    });
  }

  void _abrir(RubricaContabilista rubrica) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RubricaMesesPage(rubrica: rubrica),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final agora = DateTime.now();
    final vivo = widget.convites
        .where((c) => c.estadoEm(agora).vivo)
        .firstOrNull;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('O passado da empresa', style: textos.labelLarge),
        const SizedBox(height: 6),
        Text(
          'O Punho compara cada mês com o mesmo mês do ano anterior. Sem esse '
          'ano escrito, a comparação fica cega durante doze meses — que são '
          'precisamente os doze em que a app tem de provar que serve.',
          style: textos.bodyMedium,
        ),
        const SizedBox(height: 20),
        _CartaoDoContabilista(
          convite: vivo,
          aCarregar: widget.aCarregarConvites,
          totalConvites: widget.convites.length,
        ),
        const _RecadosDoContabilista(),
        const SizedBox(height: 24),
        Text('As perguntas', style: textos.labelLarge),
        const SizedBox(height: 6),
        Text(
          'Pode responder a qualquer uma. O que escrever aqui fica marcado como '
          'seu, e sobrepõe-se ao que o contabilista tenha deixado em branco.',
          style: textos.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final rubrica in widget.rubricas)
          _LinhaDaRubrica(
            rubrica: rubrica,
            lacuna: widget.lacunas[rubrica.chave],
            aoTocar: () => _abrir(rubrica),
          ),
      ],
    );
  }
}

/// Quem está a responder, e o que fazer se ninguém estiver.
class _CartaoDoContabilista extends ConsumerStatefulWidget {
  const _CartaoDoContabilista({
    required this.convite,
    required this.aCarregar,
    required this.totalConvites,
  });

  final ConviteContabilista? convite;
  final bool aCarregar;
  final int totalConvites;

  @override
  ConsumerState<_CartaoDoContabilista> createState() =>
      _CartaoDoContabilistaState();
}

class _CartaoDoContabilistaState extends ConsumerState<_CartaoDoContabilista> {
  bool _ocupado = false;

  Future<void> _convidar() async {
    final dados = await abrirFormulario<_DadosDoConvite>(
      context,
      (_) => _FormularioDeConvite(substitui: widget.convite),
    );
    if (dados == null || !mounted) return;

    setState(() => _ocupado = true);
    try {
      final convite = await ref
          .read(contabilistaServiceProvider)
          .criarConvite(nome: dados.nome, email: dados.email, anos: dados.anos);
      ref.invalidate(convitesContabilistaProvider);
      if (!mounted) return;
      // O token só existe aqui. Fechado este diálogo, não há como o mostrar
      // outra vez — por isso é `barrierDismissible: false` e sem botão de
      // fechar até o link ter sido copiado ou partilhado.
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DialogoDoLink(convite: convite),
      );
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_mensagemDeErro(erro))));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _revogar(ConviteContabilista convite) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Fechar este link?'),
        content: Text(
          'O link deixa de abrir para ${convite.designacao}. '
          'O que já foi respondido fica — as respostas são da empresa, não do '
          'convite.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Fechar link'),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    setState(() => _ocupado = true);
    try {
      await ref.read(contabilistaServiceProvider).revogarConvite(convite.id);
      ref.invalidate(convitesContabilistaProvider);
      ref.invalidate(lacunasContabilistaProvider);
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_mensagemDeErro(erro))));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final cores = Theme.of(context).colorScheme;
    final convite = widget.convite;

    if (widget.aCarregar && convite == null && widget.totalConvites == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calculate_outlined, color: cores.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    convite == null
                        ? 'Ninguém está a responder'
                        : convite.designacao,
                    style: textos.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (convite == null)
              Text(
                'Quem tem estes números escritos é o contabilista. Recebe um '
                'link, abre-o no computador, preenche o que sabe e não precisa '
                'de conta nem de instalar nada.',
                style: textos.bodyMedium,
              )
            else ...[
              Text(
                '${convite.estadoEm(DateTime.now()).label} · '
                '${_mesCurto(convite.inicioReal)} a '
                '${_mesCurto(convite.mesFinal)}',
                style: textos.bodyMedium,
              ),
              if (convite.periodoEncurtado) ...[
                const SizedBox(height: 4),
                Text(
                  'Pediu-se desde ${_mesCurto(convite.mesInicial)}; ele diz '
                  'que a empresa só tem histórico a partir de '
                  '${_mesCurto(convite.inicioReal)}.',
                  style: textos.bodySmall,
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'O link não se recupera — foi mostrado uma vez. Se ele o '
                'perdeu, emita outro: o anterior deixa de abrir.',
                style: textos.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _ocupado ? null : _convidar,
                  icon: const Icon(Icons.link),
                  label: Text(
                    convite == null
                        ? 'Convidar contabilista'
                        : 'Emitir novo link',
                  ),
                ),
                if (convite != null)
                  TextButton(
                    onPressed: _ocupado ? null : () => _revogar(convite),
                    child: const Text('Fechar link'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// O que o contabilista escreveu na caixa do fim do portal.
///
/// Existe porque a caixa já existia do outro lado: ele escrevia, gravava, e o
/// texto ficava numa tabela que nenhum ecrã lia. Uma caixa assim é pior do que
/// não haver caixa nenhuma — quem escreve fica convencido de que avisou.
///
/// Não aparece quando não há recados. Um cartão vazio a dizer "sem mensagens"
/// é ruído permanente para um acontecimento raro.
class _RecadosDoContabilista extends ConsumerStatefulWidget {
  const _RecadosDoContabilista();

  @override
  ConsumerState<_RecadosDoContabilista> createState() =>
      _RecadosDoContabilistaState();
}

class _RecadosDoContabilistaState
    extends ConsumerState<_RecadosDoContabilista> {
  /// As que já foram marcadas nesta sessão. Sem isto, marcar por lidas
  /// invalidava o provider, o `build` corria outra vez e voltava a marcar.
  final _marcadas = <String>{};

  void _marcarLidas(List<MensagemContabilista> mensagens) {
    final porMarcar = mensagens
        .where((m) => m.porLer && !_marcadas.contains(m.id))
        .map((m) => m.id)
        .toList();
    if (porMarcar.isEmpty) return;
    _marcadas.addAll(porMarcar);
    // Sem `await` e sem invalidar: a marca é do lado do servidor e o realce
    // deste ecrã não tem de mudar debaixo dos olhos de quem está a ler.
    ref.read(contabilistaServiceProvider).marcarMensagensLidas(porMarcar);
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final cores = Theme.of(context).colorScheme;
    // Uma falha a ler os recados não pode levar o ecrã do histórico à frente:
    // o essencial deste ecrã são as rubricas, e essas vêm de outro sítio.
    final mensagens =
        ref.watch(mensagensContabilistaProvider).valueOrNull ??
        const <MensagemContabilista>[];
    if (mensagens.isEmpty) return const SizedBox.shrink();

    final porLer = mensagens.where((m) => m.porLer).length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _marcarLidas(mensagens);
    });

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        color: porLer > 0 ? cores.secondaryContainer : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sticky_note_2_outlined, color: cores.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      porLer > 0
                          ? 'O contabilista deixou-lhe recado'
                          : 'Recados do contabilista',
                      style: textos.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Escrito por ele na caixa do fim do portal. Fica aqui — não se '
                'responde por aqui.',
                style: textos.bodySmall,
              ),
              for (final recado in mensagens) ...[
                const SizedBox(height: 12),
                Text(_quando(recado.criadoEm), style: textos.labelSmall),
                const SizedBox(height: 2),
                // `SelectableText` porque um recado costuma trazer um número ou
                // um nome de ficheiro que se quer copiar para outro lado.
                SelectableText(recado.texto, style: textos.bodyMedium),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _quando(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year} às '
    '${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}';

class _DadosDoConvite {
  const _DadosDoConvite({this.nome, this.email, required this.anos});
  final String? nome;
  final String? email;
  final int anos;
}

class _FormularioDeConvite extends StatefulWidget {
  const _FormularioDeConvite({this.substitui});

  /// Convite que este vai substituir, se houver — para o dizer antes e não
  /// depois.
  final ConviteContabilista? substitui;

  @override
  State<_FormularioDeConvite> createState() => _FormularioDeConviteState();
}

class _FormularioDeConviteState extends State<_FormularioDeConvite> {
  final _nome = TextEditingController();
  final _email = TextEditingController();
  int _anos = 5;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final substitui = widget.substitui;
    return EcraDeFormulario(
      titulo: 'Convidar o contabilista',
      rotuloGuardar: 'Criar link',
      campos: [
        if (substitui != null)
          CampoLargo(
            Text(
              'O link de ${substitui.designacao} deixa de abrir quando este '
              'for criado.',
              style: textos.bodySmall,
            ),
          ),
        CampoDeTexto(
          controlador: _nome,
          rotulo: 'Nome',
          ajuda: 'Só para o reconhecer nesta lista',
          autofocus: true,
          capitalizacao: TextCapitalization.words,
        ),
        CampoDeTexto(
          controlador: _email,
          rotulo: 'Email',
          ajuda:
              'Opcional — o Punho não envia nada, é o senhor que entrega '
              'o link',
          teclado: TextInputType.emailAddress,
        ),
        CampoLargo(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quantos anos pedir', style: textos.labelLarge),
              const SizedBox(height: 4),
              Text(
                'Termina sempre no mês passado: o mês corrente ainda está a '
                'acontecer e ele não o tem fechado.',
                style: textos.bodySmall,
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('1')),
                  ButtonSegment(value: 3, label: Text('3')),
                  ButtonSegment(value: 5, label: Text('5')),
                ],
                selected: {_anos},
                onSelectionChanged: (s) => setState(() => _anos = s.first),
              ),
            ],
          ),
        ),
      ],
      aoGuardar: () => Navigator.pop(
        context,
        _DadosDoConvite(
          nome: _nome.text.trim().isEmpty ? null : _nome.text.trim(),
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
          anos: _anos,
        ),
      ),
    );
  }
}

/// O link, a única vez que existe.
class _DialogoDoLink extends ConsumerStatefulWidget {
  const _DialogoDoLink({required this.convite});
  final ConviteCriado convite;

  @override
  ConsumerState<_DialogoDoLink> createState() => _DialogoDoLinkState();
}

class _DialogoDoLinkState extends ConsumerState<_DialogoDoLink> {
  bool _jaLevou = false;

  String get _mensagem => mensagemContabilista(
    widget.convite,
    empresa: ref.read(operationsProvider).companyName,
  );

  Future<void> _copiarMensagem() async {
    await Clipboard.setData(ClipboardData(text: _mensagem));
    if (!mounted) return;
    setState(() => _jaLevou = true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Mensagem copiada')));
  }

  /// Mesmo caminho do convite de colaborador: `wa.me` com `url_launcher`, sem
  /// dependência nova.
  ///
  /// O token vai no URL, e um URL fica no histórico do browser quando o
  /// WhatsApp não está instalado. Não é pior do que o destino — a mensagem vai
  /// para o WhatsApp de qualquer maneira —, mas é por isso que *Copiar
  /// mensagem* está primeiro: quem quiser entregar o link por outro meio não
  /// tem de passar por aqui.
  Future<void> _enviarPorWhatsApp() async {
    final url = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(_mensagem)}',
    );
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (ok) {
      setState(() => _jaLevou = true);
      return;
    }
    await Clipboard.setData(ClipboardData(text: _mensagem));
    if (!mounted) return;
    setState(() => _jaLevou = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não abriu o WhatsApp. Mensagem copiada.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final cores = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Entregue este link'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cores.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                linkContabilista(widget.convite.token),
                style: textos.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_outlined,
                  size: 18,
                  color: cores.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Só aparece agora. O Punho guarda uma impressão digital do '
                    'link, não o link — se sair daqui sem o copiar, tem de '
                    'emitir outro.',
                    style: textos.bodySmall?.copyWith(color: cores.error),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Quem tiver este link escreve na contabilidade desta empresa. '
              'Entregue-o a quem o pediu, não o publique.',
              style: textos.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _copiarMensagem,
          child: const Text('Copiar mensagem'),
        ),
        TextButton.icon(
          onPressed: _enviarPorWhatsApp,
          icon: const Icon(Icons.send, size: 18),
          label: const Text('WhatsApp'),
        ),
        FilledButton(
          // Fechar sem levar o link é perder o link. O botão só acende depois
          // de ele ter ido para algum lado.
          onPressed: _jaLevou ? () => Navigator.pop(context) : null,
          child: const Text('Já entreguei'),
        ),
      ],
    );
  }
}

class _LinhaDaRubrica extends StatelessWidget {
  const _LinhaDaRubrica({
    required this.rubrica,
    required this.lacuna,
    required this.aoTocar,
  });

  final RubricaContabilista rubrica;
  final LacunaContabilista? lacuna;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final l = lacuna;
    final (String estado, Color cor, IconData icone) = switch (l) {
      null => ('Sem pendências', cores.primary, Icons.check_circle_outline),
      _ when l.emFalta > 0 => (
        rubrica.periodicidade == PeriodicidadeRubrica.mensal
            ? '${l.emFalta} ${l.emFalta == 1 ? 'mês' : 'meses'} em branco'
            : 'Por responder',
        cores.error,
        Icons.error_outline,
      ),
      _ when l.soAnual > 0 => (
        '${l.soAnual} ${l.soAnual == 1 ? 'mês' : 'meses'} só com o total do ano',
        cores.tertiary,
        Icons.trending_flat,
      ),
      _ => ('Sem pendências', cores.primary, Icons.check_circle_outline),
    };

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icone, color: cor),
      title: Text(rubrica.rotulo),
      subtitle: Text(estado, style: TextStyle(color: cor)),
      trailing: const Icon(Icons.chevron_right),
      onTap: aoTocar,
    );
  }
}

class _Falha extends StatelessWidget {
  const _Falha({required this.erro});
  final Object erro;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: Theme.of(context).hintColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Não foi possível ler o histórico.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _mensagemDeErro(erro),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

/// A mensagem do Postgres já vem escrita para gente ("Esse mês ainda não
/// aconteceu."). Mostrá-la é melhor do que traduzi-la aqui e ficar com duas
/// versões da mesma recusa.
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

const _mesesCurtos = [
  'Jan',
  'Fev',
  'Mar',
  'Abr',
  'Mai',
  'Jun',
  'Jul',
  'Ago',
  'Set',
  'Out',
  'Nov',
  'Dez',
];

String _mesCurto(DateTime d) => '${_mesesCurtos[d.month - 1]}/${d.year}';
