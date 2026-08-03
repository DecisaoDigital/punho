import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/operations/kpis.dart';
import '../../../core/operations/operations_controller.dart';
import '../../operations/presentation/operational_pages.dart';
import 'finance_pages.dart';

/// Destino Finanças: onde se registam e consultam movimentos.
///
/// Estas acções viviam no fundo do painel de gestão, atrás de dezassete
/// métricas — o gestor tinha de percorrer o ecrã todo para registar uma
/// despesa. O painel passou a carrossel de leitura e as acções ganharam sítio
/// próprio na barra lateral.
class FinancasPage extends ConsumerWidget {
  const FinancasPage({super.key, this.agora});

  /// Injectável para os testes não dependerem do dia em que correm.
  final DateTime? agora;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Finanças',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text('Registar movimentos e consultar o que entrou e saiu.'),
        const SizedBox(height: 20),
        _PrevisaoDoMesCard(agora: agora),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Accao(
              icone: Icons.add_circle_outline,
              texto: 'Registar recebimento',
              principal: true,
              onTap: () => _abrir(context, const RegisterReceiptPage()),
            ),
            _Accao(
              icone: Icons.remove_circle_outline,
              texto: 'Registar despesa',
              principal: true,
              onTap: () => _abrir(context, const RegisterExpensePage()),
            ),
            _Accao(
              icone: Icons.account_balance_wallet_outlined,
              texto: 'Recebimentos',
              onTap: () => _abrir(
                context,
                const FinanceListPage(title: 'Recebimentos', expenses: false),
              ),
            ),
            _Accao(
              icone: Icons.receipt_long_outlined,
              texto: 'Despesas',
              onTap: () => _abrir(
                context,
                const FinanceListPage(title: 'Despesas', expenses: true),
              ),
            ),
            _Accao(
              icone: Icons.history_outlined,
              texto: 'Histórico mensal',
              onTap: () => _abrir(context, const HistoricalDataPage()),
            ),
          ],
        ),
      ],
    ),
  );

  void _abrir(BuildContext context, Widget pagina) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => pagina));
}

/// Como o mês deve fechar — diferente do "Encontro de contas" do painel, que
/// é só o que já aconteceu até hoje.
///
/// Entradas previstas incluem o valor por receber das reservas já na agenda;
/// saídas previstas somam os custos fixos declarados com a média do que se
/// gastou em despesas variáveis no mês passado e no mesmo mês do ano passado.
/// Ver o comentário em [previsaoDoMes] (`core/operations/kpis.dart`) para o
/// porquê de não ser a mesma conta do "Encontro de contas".
class _PrevisaoDoMesCard extends ConsumerWidget {
  const _PrevisaoDoMesCard({this.agora});

  final DateTime? agora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(operationsProvider);
    final previsao = previsaoDoMes(estado, agora ?? DateTime.now());
    final saidas = previsao.saidasPrevistasCents;
    final saldo = previsao.saldoPrevistoCents;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Previsão do mês',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _linhaPrevisao(
                    context,
                    'Entradas previstas',
                    _money(previsao.entradasPrevistasCents),
                  ),
                ),
                Expanded(
                  child: _linhaPrevisao(
                    context,
                    'Saídas previstas',
                    saidas == null ? 'Por apurar' : _money(saidas),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (saldo == null)
              Text(
                'Indica os custos fixos mensais em Empresa › Dados para '
                'prever o saldo.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Text(
                'Saldo previsto: '
                '${saldo >= 0 ? '+ ' : '− '}${_money(saldo.abs())}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: saldo >= 0
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _linhaPrevisao(BuildContext context, String rotulo, String valor) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: Theme.of(context).textTheme.bodySmall),
          Text(
            valor,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      );
}

String _money(int cents) =>
    '${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')} €';

class _Accao extends StatelessWidget {
  const _Accao({
    required this.icone,
    required this.texto,
    required this.onTap,
    this.principal = false,
  });

  final IconData icone;
  final String texto;
  final VoidCallback onTap;
  final bool principal;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 230,
    height: 52,
    child: principal
        ? FilledButton.icon(
            onPressed: onTap,
            icon: Icon(icone),
            label: Text(texto),
          )
        : OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icone),
            label: Text(texto),
          ),
  );
}
