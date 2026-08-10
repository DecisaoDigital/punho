import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/finance/regime_fiscal.dart';
import '../../../core/navigation/app_destination.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../domain/models/finance.dart';
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
        const CompanySettingsPage(embutida: true),
        _AbaRegimeFiscal(aoIrParaDados: () => _abas.animateTo(0)),
        const HistoricoContabilistaPage(),
        _AbaCustosFixos(aoIrParaDados: () => _abas.animateTo(0)),
        const VehiclesPage(),
        const FinancasPage(),
        const _AbaEstado(),
      ],
    ),
  );
}

/// Leitura do regime fiscal, com o caminho para o alterar.
///
/// Só leitura de propósito: mudar de regime muda o significado de metade dos
/// KPIs financeiros (Decisão 1), e um selector solto aqui deixaria isso
/// acontecer sem que ninguém percebesse o alcance. O motor da mudança é sprint
/// própria; até lá altera-se onde já se alterava — a forma jurídica, nos Dados.
class _AbaRegimeFiscal extends ConsumerWidget {
  const _AbaRegimeFiscal({required this.aoIrParaDados});

  final VoidCallback aoIrParaDados;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(operationsProvider);
    final regime = regimeDaFormaJuridica(estado.legalForm);
    final textos = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Regime actual', style: textos.labelLarge),
        const SizedBox(height: 6),
        Text(rotuloDeRegime(regime), style: textos.headlineSmall),
        const SizedBox(height: 4),
        Text(
          estado.legalForm.trim().isEmpty
              ? 'Ainda não indicaste a forma jurídica.'
              : 'Deduzido de "${estado.legalForm}".',
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
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: aoIrParaDados,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar em Dados →'),
          ),
        ),
      ],
    );
  }
}

/// Custos fixos mensais — leitura, com o caminho para os editar por rubrica.
///
/// Só leitura de propósito, mesma ideia da [_AbaRegimeFiscal]: o editor por
/// rubrica (renda, água e luz, comunicações, seguros — ver
/// `_EditorDeCustosFixos` em `company_settings_page.dart`) já existe e grava a
/// sério, mas vive dentro do formulário de Dados, que é quem controla o save.
/// Duplicar aqui um segundo editor com o seu próprio estado arriscava as duas
/// cópias divergirem; um botão a saltar para lá é mais seguro do que isso.
class _AbaCustosFixos extends ConsumerWidget {
  const _AbaCustosFixos({required this.aoIrParaDados});

  final VoidCallback aoIrParaDados;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(operationsProvider);
    final valor = estado.custoFixoMensalCents;
    final rubricas = estado.custosFixos;
    final textos = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Custos fixos mensais', style: textos.labelLarge),
        const SizedBox(height: 6),
        Text(
          valor == null
              ? 'Por indicar'
              : '${(valor / 100).toStringAsFixed(2)} €',
          style: textos.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Renda, electricidade, água, comunicações, seguros e outros custos '
          'que se repetem todos os meses. Entram no cálculo do peso dos custos '
          'sobre a receita.',
          style: textos.bodyMedium,
        ),
        const SizedBox(height: 20),
        if (rubricas.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Por rubrica', style: textos.labelLarge),
                  const SizedBox(height: 8),
                  for (final rubrica in rubricas)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              rubrica.descricao.trim().isEmpty
                                  ? expenseCategoryLabel(rubrica.categoria)
                                  : '${expenseCategoryLabel(rubrica.categoria)} — ${rubrica.descricao}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${(rubrica.valorCents / 100).toStringAsFixed(2)} €',
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: aoIrParaDados,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar por rubrica em Dados →'),
          ),
        ),
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
                  for (final c in lista) _cartaoConflito(theme, c),
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
        const SizedBox(height: 28),
        _placeholderFiscal(theme),
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

  Widget _cartaoConflito(ThemeData theme, OperacaoRecusada c) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Icon(
        Icons.event_busy_outlined,
        color: theme.colorScheme.error,
      ),
      title: const Text('Máquina já reservada nesse período'),
      subtitle: Text('Marcação ${c.operacao.entidadeId}'),
    ),
  );

  Widget _placeholderFiscal(ThemeData theme) => Row(
    children: [
      Icon(Icons.event_note_outlined, color: theme.hintColor, size: 20),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'Timeline de obrigações fiscais — em preparação.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
      ),
    ],
  );
}
