import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/campos.dart';
import '../../../core/finance/regime_fiscal.dart';
import '../../../core/navigation/app_destination.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../domain/models/finance.dart';
import '../../../domain/models/operations.dart';
import '../../company/presentation/company_settings_page.dart';
import '../../contabilista/presentation/historico_contabilista_page.dart';
import '../../finance/presentation/financas_page.dart';
import '../../sync/sync_providers.dart';
import '../../workforce/presentation/workforce_pages.dart';
import '../../../core/sync/registo_de_operacoes.dart';

/// Tudo o que é da empresa, num sítio só (Decisão 2).
///
/// A barra lateral tinha oito destinos e crescia a cada funcionalidade. Três
/// deles — dados da empresa, veículos, finanças — não são sítios onde se
/// trabalha todos os dias: são o retrato da empresa, que se consulta e corrige
/// de vez em quando. Juntá-los em abas liberta a barra para o que é operação
/// diária e dá um lugar óbvio às coisas que ainda vão nascer (regime fiscal,
/// obrigações do Estado).
class EmpresaPage extends ConsumerStatefulWidget {
  const EmpresaPage({super.key, this.abaInicial = AbaDaEmpresa.dados});

  /// Permite entrar directamente numa aba. É o que mantém vivos os saltos que
  /// antes iam para "Finanças" ou "Veículos" como destinos próprios.
  final AbaDaEmpresa abaInicial;

  @override
  ConsumerState<EmpresaPage> createState() => _EmpresaPageState();
}

class _EmpresaPageState extends ConsumerState<EmpresaPage>
    with SingleTickerProviderStateMixin {
  late final TabController _abas = TabController(
    length: AbaDaEmpresa.values.length,
    initialIndex: widget.abaInicial.index,
    vsync: this,
  );

  @override
  void dispose() {
    _abas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      // Sem title: as 6 tabs ganham a area toda. O nome 'Empresa' ja aparece
      // no destino da sidebar e no rotulo permanente da app; repeti-lo aqui
      // so gastava vertical num telemovel.
      toolbarHeight: 0,
      bottom: TabBar(
        controller: _abas,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerHeight: 0,
        tabs: [
          for (final aba in AbaDaEmpresa.values)
            Tab(
              height: 52,
              iconMargin: const EdgeInsets.only(bottom: 2),
              icon: Icon(aba.icon, size: 23),
              text: aba.label,
            ),
        ],
      ),
    ),
    body: TabBarView(
      controller: _abas,
      children: [
        const _AbaDados(),
        const _AbaRegimeFiscal(),
        const HistoricoContabilistaPage(),
        const _AbaCustosFixos(),
        const VehiclesPage(),
        const FinancasPage(),
        const _AbaEstado(),
      ],
    ),
  );
}

/// **Dados** — o retrato da empresa, para se ler.
///
/// Esta aba era o formulário inteiro: cinco cartões, vinte campos de texto e o
/// editor de custos fixos, tudo aberto ao mesmo tempo. O César, a 10 de Agosto
/// de 2026: «visualmente é muita informação, não tem fluxo de trabalho e
/// visual», e a seguir: «Dados deve mostrar os dados referentes à empresa; se
/// for para editar é outra situação».
///
/// São dois gestos diferentes e passam a ser dois ecrãs. Ler é o que se faz
/// quase sempre — confirmar o NIF antes de o ditar ao telefone, ver a morada —
/// e ler vinte caixas de input é trabalho a mais para isso. Editar é raro, e
/// quando acontece merece o ecrã todo e um Guardar só dele.
///
/// O que aqui não está: os custos fixos. Têm aba própria, e ali editam-se.
class _AbaDados extends ConsumerWidget {
  const _AbaDados();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(operationsProvider);
    final textos = Theme.of(context).textTheme;
    final morada = [
      estado.companyAddress,
      [
        estado.companyPostalCode,
        estado.companyLocality,
      ].where(_temTexto).join(' '),
    ].where(_temTexto).join('\n');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        Text(
          estado.companyName.trim().isEmpty
              ? 'Empresa sem nome'
              : estado.companyName,
          style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (_temTexto(estado.legalForm)) ...[
          const SizedBox(height: 2),
          Text(estado.legalForm, style: textos.bodyMedium),
        ],
        const SizedBox(height: 20),
        _Retrato(
          icone: Icons.badge_outlined,
          titulo: 'Identificação',
          linhas: [
            ('Responsável', estado.ownerName),
            ('NIF', estado.companyTaxId),
          ],
        ),
        _Retrato(
          icone: Icons.place_outlined,
          titulo: 'Contactos e morada',
          linhas: [
            ('Telemóvel', estado.companyPhone),
            ('Email', estado.companyEmail),
            ('Morada', morada.isEmpty ? null : morada),
          ],
        ),
        _Retrato(
          icone: Icons.groups_outlined,
          titulo: 'Equipa e frota',
          linhas: [
            ('Colaboradores', '${estado.declaredCollaboratorCount}'),
            ('Veículos', '${estado.declaredVehicleCount}'),
            (
              'Máquinas declaradas',
              '${estado.totalMachinesDeclared}'
                  '${estado.machinesStillToIdentify > 0 ? ' · faltam identificar ${estado.machinesStillToIdentify}' : ''}',
            ),
          ],
        ),
        _Retrato(
          icone: Icons.query_stats_outlined,
          titulo: 'Referências financeiras',
          linhas: [
            ('Facturação do ano passado', _euros(estado.revenueLastYearCents)),
            ('Facturação deste ano', _euros(estado.revenueThisYearCents)),
            (
              'Manutenção no ano passado',
              _euros(estado.maintenanceLastYearCents),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CompanySettingsPage(),
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar dados da empresa'),
          ),
        ),
      ],
    );
  }
}

bool _temTexto(String? valor) => valor != null && valor.trim().isNotEmpty;

String? _euros(int? cents) => cents == null ? null : '${textoDeCents(cents)} €';

/// Um bloco do retrato: rótulo à esquerda, valor à direita, uma linha cada.
///
/// O que está por preencher diz-o — «Por indicar», em cinzento. Esconder a
/// linha faria a ficha parecer completa, e é justamente o que falta que se quer
/// ver antes de carregar em Editar.
class _Retrato extends StatelessWidget {
  const _Retrato({
    required this.icone,
    required this.titulo,
    required this.linhas,
  });

  final IconData icone;
  final String titulo;
  final List<(String, String?)> linhas;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final cores = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 18, color: cores.outline),
              const SizedBox(width: 8),
              Text(
                titulo.toUpperCase(),
                style: textos.labelSmall?.copyWith(
                  color: cores.outline,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final (rotulo, valor) in linhas)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 132,
                    child: Text(rotulo, style: textos.bodyMedium),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _temTexto(valor) ? valor! : 'Por indicar',
                      style: _temTexto(valor)
                          ? textos.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            )
                          : textos.bodyMedium?.copyWith(color: cores.outline),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// O regime fiscal — lê-se, e **muda-se aqui**.
///
/// Era só leitura, e o único gesto da aba era «Editar em Dados →». O mesmo
/// desvio que os custos fixos tinham: uma aba cujo único botão te manda para
/// outra aba não é uma aba.
///
/// O receio que a mantinha assim continua a ser verdade — mudar de regime muda
/// o significado de metade dos KPIs financeiros (Decisão 1), e um selector
/// solto deixava isso acontecer sem ninguém perceber o alcance. Mas escondê-lo
/// nos Dados não resolvia nada: lá está solto na mesma, no meio de vinte
/// campos, e sem uma linha a dizer o que decide. Fica aqui, encostado ao que
/// decide, e a mudança que altera mesmo o regime pede confirmação.
///
/// O que continua fora daqui é o motor de mudança de regime (reprocessar o
/// passado com as regras novas). Isso é sprint própria; o que muda hoje é como
/// se lêem os números daqui para a frente.
class _AbaRegimeFiscal extends ConsumerStatefulWidget {
  const _AbaRegimeFiscal();

  @override
  ConsumerState<_AbaRegimeFiscal> createState() => _AbaRegimeFiscalState();
}

class _AbaRegimeFiscalState extends ConsumerState<_AbaRegimeFiscal> {
  /// A escolha por gravar. Nula enquanto ninguém mexeu — aí o que está no ecrã
  /// é o que está gravado.
  String? _escolhida;

  Future<void> _guardar(String escolhida, RegimeFiscal antes) async {
    final depois = regimeDaFormaJuridica(escolhida);
    if (depois != antes && !await _confirmar(antes, depois)) return;
    if (!mounted) return;
    ref
        .read(operationsProvider.notifier)
        .updateCompanySettings(legalForm: escolhida);
    setState(() => _escolhida = null);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Regime guardado: ${rotuloDeRegime(depois)}.')),
      );
  }

  /// Só quando o regime muda mesmo. Trocar "Lda." por "Sociedade por quotas"
  /// dá o mesmo regime, e parar quem escreve o nome certo da empresa para lhe
  /// perguntar se tem a certeza é ruído.
  Future<bool> _confirmar(RegimeFiscal antes, RegimeFiscal depois) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogo) => AlertDialog(
          title: const Text('Mudar de regime?'),
          content: Text(
            'De «${rotuloDeRegime(antes)}» para «${rotuloDeRegime(depois)}».\n\n'
            'Muda o que a app calcula: a carga social da entidade patronal, o '
            'líquido estimado dos colaboradores e o custo com pessoal no '
            'painel. O que já aconteceu não se reescreve — passa é a ser lido '
            'com as regras novas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogo).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogo).pop(true),
              child: const Text('Mudar de regime'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(operationsProvider);
    final guardada = estado.legalForm.trim();
    final escolhida = _escolhida ?? guardada;
    final regime = regimeDaFormaJuridica(guardada);
    final regimeEscolhido = regimeDaFormaJuridica(escolhida);
    final porGravar = escolhida != guardada;
    final textos = Theme.of(context).textTheme;
    final cores = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Regime actual', style: textos.labelLarge),
        const SizedBox(height: 6),
        Text(rotuloDeRegime(regime), style: textos.headlineSmall),
        const SizedBox(height: 4),
        Text(
          guardada.isEmpty
              ? 'Ainda não indicaste a forma jurídica.'
              : 'Deduzido de "$guardada".',
          style: textos.bodySmall,
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('O que isto decide', style: textos.labelLarge),
                const SizedBox(height: 8),
                Text(
                  regime == RegimeFiscal.outro
                      ? 'Esta forma jurídica ainda não é modelada, por isso as '
                            'estimativas de custo com pessoal não aparecem — em '
                            'vez de aparecerem erradas.'
                      : 'A carga social da entidade patronal, a estimativa de '
                            'líquido dos colaboradores e o custo real com '
                            'pessoal no painel. Mudar de regime muda estes '
                            'números.',
                  style: textos.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Mudar de regime', style: textos.labelLarge),
        const SizedBox(height: 6),
        Text(
          'O regime não se escolhe à mão: sai da forma jurídica da empresa. '
          'Muda-se aqui, que é onde se vê o que ela decide.',
          style: textos.bodyMedium,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: escolhida.isEmpty ? null : escolhida,
          decoration: const InputDecoration(
            labelText: 'Forma jurídica',
            border: OutlineInputBorder(),
          ),
          hint: const Text('Por indicar'),
          items: [
            // A guardada entra na lista mesmo que já não seja oferecida: sem
            // isso, uma ficha antiga com outra forma jurídica abria o
            // dropdown sem opção correspondente e rebentava.
            for (final forma in {
              ...formasJuridicas,
              if (guardada.isNotEmpty) guardada,
            })
              DropdownMenuItem(value: forma, child: Text(forma)),
          ],
          onChanged: (valor) => setState(() => _escolhida = valor),
        ),
        if (porGravar) ...[
          const SizedBox(height: 10),
          Text(
            regimeEscolhido == regime
                ? 'Continua em ${rotuloDeRegime(regime)}.'
                : 'Passa a ${rotuloDeRegime(regimeEscolhido)}.',
            style: textos.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: regimeEscolhido == regime ? null : cores.error,
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            FilledButton.icon(
              onPressed: porGravar ? () => _guardar(escolhida, regime) : null,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar forma jurídica'),
            ),
            const SizedBox(width: 12),
            if (porGravar)
              Flexible(
                child: Text(
                  'Por guardar',
                  style: textos.bodySmall?.copyWith(color: cores.error),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Custos fixos mensais — **editam-se aqui**.
///
/// Era só leitura, e o único botão da aba era «Editar por rubrica em Dados →».
/// O César, a 10 de Agosto de 2026: «custos fixos remete para Dados… não pode».
/// Tinha razão: uma aba cujo único gesto é mandar-te para outra aba não é uma
/// aba — é um desvio, e ainda por cima para um formulário de vinte campos onde
/// as rubricas estão lá para o fim.
///
/// O medo que a mantinha em leitura era o de ter duas cópias do editor a
/// divergir. Não há duas: o [EditorDeCustosFixos] é o mesmo widget que os Dados
/// usam. O que muda é quem grava — aqui grava-se só as rubricas, sem tocar em
/// mais nada da ficha.
class _AbaCustosFixos extends ConsumerStatefulWidget {
  const _AbaCustosFixos();

  @override
  ConsumerState<_AbaCustosFixos> createState() => _AbaCustosFixosState();
}

class _AbaCustosFixosState extends ConsumerState<_AbaCustosFixos> {
  /// Cópia de trabalho. O que está no ecrã só passa a ser verdade quando se
  /// carrega em Guardar — sair a meio de escrever a renda não deixa meia renda
  /// gravada.
  late List<CustoFixo> _rubricas = List.of(
    ref.read(operationsProvider).custosFixos,
  );

  /// Mensagem por id de rubrica, para o campo de valor.
  final Map<String, String> _erros = {};

  bool get _porGravar {
    final gravadas = ref.read(operationsProvider).custosFixos;
    if (gravadas.length != _rubricas.length) return true;
    for (var i = 0; i < _rubricas.length; i++) {
      final a = gravadas[i];
      final b = _rubricas[i];
      if (a.id != b.id ||
          a.categoria != b.categoria ||
          a.descricao != b.descricao ||
          a.valorCents != b.valorCents ||
          a.diaDoMes != b.diaDoMes) {
        return true;
      }
    }
    return false;
  }

  void _guardar() {
    // Gravar com um valor ilegível no ecrã guardaria o valor anterior sem o
    // dizer — a mesma mentira do `?? 0`, só mais discreta. Mesma regra dos
    // Dados.
    if (_erros.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Há valores por corrigir. Nada foi guardado.'),
          ),
        );
      return;
    }
    ref
        .read(operationsProvider.notifier)
        .updateCompanySettings(
          // O total redondo deixa de ser escrito: quem manda são as rubricas.
          // Duas respostas à mesma pergunta é uma a mais.
          fixedMonthlyCostsCents: const Campo(null),
          custosFixos: List.of(_rubricas),
        );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Custos fixos guardados.')));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(operationsProvider);
    final total = totalDeCustosFixos(_rubricas);
    final textos = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Custos fixos mensais', style: textos.labelLarge),
        const SizedBox(height: 6),
        Text(
          total == null ? 'Por indicar' : '${textoDeCents(total)} €',
          style: textos.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Renda, electricidade, água, comunicações, seguros e outros custos '
          'que se repetem todos os meses. São eles que fazem os «Gastos '
          'previstos do mês» e o «Saldo previsto» deixarem de estar por apurar.',
          style: textos.bodyMedium,
        ),
        const SizedBox(height: 20),
        EditorDeCustosFixos(
          rubricas: _rubricas,
          aoMudar: (novas) => setState(() => _rubricas = novas),
          erros: _erros,
          aoMudarErro: (id, mensagem) => setState(() {
            if (mensagem == null) {
              _erros.remove(id);
            } else {
              _erros[id] = mensagem;
            }
          }),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            FilledButton.icon(
              onPressed: _porGravar ? _guardar : null,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar custos fixos'),
            ),
            const SizedBox(width: 12),
            if (_porGravar)
              Flexible(
                child: Text(
                  'Por guardar',
                  style: textos.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
        // A ficha da empresa continua a ser o sítio do resto: o NIF, a morada,
        // a forma jurídica. Isto é um atalho, não um desvio — a aba já fez o
        // trabalho dela antes de o oferecer.
        if (estado.onboarded) ...[
          const SizedBox(height: 24),
          Text(
            'O resto da ficha da empresa — NIF, morada, forma jurídica — '
            'continua na aba Dados.',
            style: textos.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// Estado da empresa para o gestor. Hoje mostra os **conflitos de reserva a
/// resolver** — marcações que o servidor barrou por sobreposição (`23P01`) e
/// que saíram da fila de sync para não a trancar. A timeline de obrigações
/// fiscais entra aqui mais tarde.
class _AbaEstado extends ConsumerWidget {
  const _AbaEstado();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final conflitos = ref.watch(conflitosDeReservaProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Conflitos de reserva', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Marcações que o servidor barrou por a máquina já estar reservada '
          'nesse período. Saíram da fila para não a prender — resolve-as aqui '
          '(remarcar ou recusar).',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 12),
        ...conflitos.when<List<Widget>>(
          loading: () => const [LinearProgressIndicator()],
          error: (e, _) => [
            Text(
              'Não foi possível ler os conflitos: $e',
              style: theme.textTheme.bodySmall,
            ),
          ],
          data: (lista) => lista.isEmpty
              ? [_linhaTudoEmDia(theme)]
              : [
                  for (final c in lista) _CartaoDeConflito(c),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final motor = await ref.read(motorSyncProvider.future);
                        await motor?.registo.limparConflitosDeReserva();
                        ref.invalidate(conflitosDeReservaProvider);
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Já resolvi — limpar a lista'),
                    ),
                  ),
                ],
        ),
      ],
    );
  }

  Widget _linhaTudoEmDia(ThemeData theme) => Row(
    children: [
      Icon(
        Icons.check_circle_outline,
        color: theme.colorScheme.primary,
        size: 20,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'Sem conflitos — as marcações não têm sobreposições.',
          style: theme.textTheme.bodyMedium,
        ),
      ),
    ],
  );
}

/// Um conflito de reserva, com as duas saídas que o texto por cima promete.
///
/// Mostrava «Marcação b1786396745111605» e mais nada: o id em bruto, e zero
/// botões debaixo de uma frase que diz «resolve-as aqui (remarcar ou recusar)».
/// O César apanhou-o no telemóvel a 10 de Agosto de 2026.
///
/// Quem sabe o que a marcação é não é o payload da operação recusada — é o
/// **estado local**, que continua a tê-la (foi gravada cá antes de sair, e o
/// servidor só a recusou depois). Daí virem de lá o cliente, as máquinas e o
/// período. Quando lá não estiver — apagada entretanto, ou vinda de um
/// telemóvel que já não é este — diz-se isso, e a única saída é tirar da lista.
class _CartaoDeConflito extends ConsumerWidget {
  const _CartaoDeConflito(this.conflito);

  final OperacaoRecusada conflito;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final estado = ref.watch(operationsProvider);
    final reserva = estado.bookings
        .where((b) => b.id == conflito.operacao.entidadeId)
        .firstOrNull;
    final maquinas = reserva == null
        ? ''
        : estado.machines
              .where((m) => reserva.machineIds.contains(m.id))
              .map((m) => m.name)
              .join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(
              Icons.event_busy_outlined,
              color: theme.colorScheme.error,
            ),
            title: Text(
              reserva == null
                  ? 'Marcação que já não está neste telemóvel'
                  : '${maquinas.isEmpty ? 'Máquina' : maquinas} · '
                        '${_periodo(reserva)}',
            ),
            subtitle: Text(
              reserva == null
                  ? conflito.paraPessoa
                  : '${reserva.customerNameSnapshot} · já estava reservada '
                        'nesse período',
            ),
          ),
          if (reserva == null)
            OverflowBar(
              alignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _resolver(context, ref),
                  child: const Text('Tirar da lista'),
                ),
              ],
            )
          else
            OverflowBar(
              alignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _recusar(context, ref, reserva),
                  child: const Text('Recusar'),
                ),
                FilledButton(
                  onPressed: () => _remarcar(context, ref, reserva),
                  child: const Text('Remarcar'),
                ),
              ],
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  /// Só o dia de início se escolhe: a duração vem como está. Ver
  /// [OperationsController.remarcarPara].
  Future<void> _remarcar(
    BuildContext context,
    WidgetRef ref,
    Booking reserva,
  ) async {
    final hoje = DateTime.now();
    final primeiro = DateTime(hoje.year - 1);
    final novoDia = await showDatePicker(
      context: context,
      initialDate: reserva.startsAt.isBefore(primeiro)
          ? primeiro
          : reserva.startsAt,
      firstDate: primeiro,
      lastDate: DateTime(hoje.year + 2, 12, 31),
      helpText: 'Novo dia de início',
    );
    if (novoDia == null || !context.mounted) return;

    final choque = ref
        .read(operationsProvider.notifier)
        .remarcarPara(reserva.id, novoDia);
    if (choque != null) {
      // Não se tira da lista: o conflito continua por resolver, e dizer o
      // contrário era a mesma mentira noutro sítio.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${choque.machine.name} também está ocupada nesse dia '
              '(${choque.booking.customerNameSnapshot}). Nada mudou.',
            ),
          ),
        );
      return;
    }
    await _resolver(context, ref, aviso: 'Remarcada para ${_data(novoDia)}.');
  }

  Future<void> _recusar(
    BuildContext context,
    WidgetRef ref,
    Booking reserva,
  ) async {
    final certo = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Recusar a marcação?'),
        content: Text(
          '${reserva.customerNameSnapshot}, ${_periodo(reserva)}.\n\n'
          'Fica cancelada e a máquina volta a ficar livre nesse período. '
          'Quem combinou com o cliente tens de ser tu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Voltar atrás'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Recusar'),
          ),
        ],
      ),
    );
    if (certo != true || !context.mounted) return;
    ref
        .read(operationsProvider.notifier)
        .updateBookingStatus(reserva.id, BookingStatus.cancelled);
    await _resolver(context, ref, aviso: 'Marcação recusada.');
  }

  /// Tira **este** conflito da lista, e não os outros — ver
  /// [RegistoDeOperacoes.resolverConflitoDeReserva].
  Future<void> _resolver(
    BuildContext context,
    WidgetRef ref, {
    String? aviso,
  }) async {
    final motor = await ref.read(motorSyncProvider.future);
    await motor?.registo.resolverConflitoDeReserva(conflito.operacao.id);
    if (!context.mounted) return;
    ref.invalidate(conflitosDeReservaProvider);
    if (aviso != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(aviso)));
    }
  }
}

String _data(DateTime dia) =>
    '${dia.day.toString().padLeft(2, '0')}/${dia.month.toString().padLeft(2, '0')}';

/// O período em palavras de quem marca, não em `DateTime`.
///
/// A convenção das reservas: meio dia é 00:00→12:00 ou 12:00→24:00, um dia
/// inteiro acaba à meia-noite seguinte, e vários dias acabam à meia-noite a
/// seguir ao último. Por isso o último dia é o fim menos um minuto — mostrar o
/// `endsAt` cru dava sempre mais um dia do que o que está reservado.
String _periodo(Booking reserva) {
  final dias =
      reserva.endsAt.difference(reserva.startsAt).inMinutes / (60 * 24);
  final inicio = _data(reserva.startsAt);
  if (dias <= 0.5) {
    return reserva.startsAt.hour < 12 ? '$inicio de manhã' : '$inicio à tarde';
  }
  if (dias <= 1) return inicio;
  return '$inicio a ${_data(reserva.endsAt.subtract(const Duration(minutes: 1)))}';
}
