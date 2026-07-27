import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_config.dart';
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
  const FinancasPage({super.key});

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
            if (SupabaseConfig.enabled) const _BotaoSincronizar(),
          ],
        ),
      ],
    ),
  );

  void _abrir(BuildContext context, Widget pagina) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => pagina));
}

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

class _BotaoSincronizar extends ConsumerWidget {
  const _BotaoSincronizar();

  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
    width: 230,
    height: 52,
    child: OutlinedButton.icon(
      onPressed: () async {
        final status = await ref
            .read(operationsProvider.notifier)
            .synchronizeRemote();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensagemDeSincronizacao(status.name))),
        );
      },
      icon: const Icon(Icons.sync),
      label: const Text('Sincronizar'),
    ),
  );
}

String mensagemDeSincronizacao(String status) => switch (status) {
  'synchronized' => 'Dados sincronizados com segurança.',
  'pendingChanges' =>
    'Sem ligação. As alterações ficam guardadas neste dispositivo.',
  'requiresReview' =>
    'Existe uma alteração remota por rever antes de sincronizar.',
  _ => 'A sincronização está em curso.',
};
