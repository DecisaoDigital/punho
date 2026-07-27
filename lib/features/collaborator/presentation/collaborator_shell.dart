import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../core/orientacao/orientacao_do_contexto.dart';
import '../../../core/session/demo_session.dart';
import '../../../domain/models/operations.dart';
import '../../finance/presentation/finance_pages.dart';
import '../../operations/presentation/operational_pages.dart';

class CollaboratorShell extends ConsumerStatefulWidget {
  const CollaboratorShell({super.key, this.collaboratorId, this.titulo});

  /// Identidade do colaborador autenticado. Quando é nula cai-se na sessão de
  /// demonstração local — é o caminho usado sem Supabase.
  final String? collaboratorId;
  final String? titulo;

  @override
  ConsumerState<CollaboratorShell> createState() => _CollaboratorShellState();
}

class _CollaboratorShellState extends ConsumerState<CollaboratorShell> {
  @override
  void initState() {
    super.initState();
    // Telemóvel na mão, no terreno, seis botões grandes. Portrait, como todo o
    // resto da app fora do painel do gestor (Decisão 13).
    OrientacaoDoContexto.portraitJa();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(demoSessionProvider);
    // Era `session.collaboratorId!`: com Supabase ligado a sessão de
    // demonstração é sempre `manager`, cujo id é nulo, e o `!` rebentava.
    final id = widget.collaboratorId ?? session.collaboratorId;
    if (id == null) return const _SemColaborador();
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo ?? session.label)),
      body: SafeArea(
        // ListView e não Column: seis botões de 76 dp não cabem numa janela
        // baixa (Windows, ou telemóvel em paisagem) e o ecrã aparecia com as
        // barras amarelas e pretas de overflow.
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'O que quer registar?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            _Action(
              'Nova marcação',
              Icons.add_task,
              () => _newBooking(context, ref, id),
            ),
            _Action(
              'Registar recebimento',
              Icons.payments,
              () => _receipt(context, ref, id),
            ),
            _Action(
              'Registar despesa / fatura',
              Icons.receipt_long_outlined,
              () => _expense(context, id),
            ),
            _Action(
              'Nova lead',
              Icons.person_add_alt_1,
              () => _newLead(context, ref, id),
            ),
            _Action(
              'As minhas marcações',
              Icons.calendar_month,
              () => _mine(context, ref, id),
            ),
            _Action(
              'A minha atividade',
              Icons.timeline,
              () => _activity(context, ref, id),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sessão sem colaborador associado. Antes disto o ecrã rebentava com um null
/// check; mostrar o estado é sempre melhor do que estoirar em frente ao cliente.
class _SemColaborador extends StatelessWidget {
  const _SemColaborador();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.badge_outlined, size: 48),
            SizedBox(height: 16),
            Text(
              'Sem colaborador associado a esta sessão.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action(this.text, this.icon, this.onTap);
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: SizedBox(
      height: 76,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(text),
      ),
    ),
  );
}

void _newBooking(BuildContext c, WidgetRef ref, String id) {
  Navigator.push(
    c,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Nova marcação')),
        body: BookingsPage(responsibleId: id),
      ),
    ),
  );
}

void _receipt(BuildContext c, WidgetRef ref, String id) {
  Navigator.push(
    c,
    MaterialPageRoute(
      builder: (_) => RegisterReceiptPage(recordedByCollaboratorId: id),
    ),
  );
}

void _expense(BuildContext c, String id) {
  Navigator.push(
    c,
    MaterialPageRoute(
      builder: (_) => RegisterExpensePage(recordedByCollaboratorId: id),
    ),
  );
}

Future<void> _newLead(BuildContext c, WidgetRef ref, String id) async {
  final name = TextEditingController();
  final phone = TextEditingController();
  await showDialog<void>(
    context: c,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Nova lead'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Telemóvel'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty || phone.text.trim().isEmpty) return;
            ref
                .read(operationsProvider.notifier)
                .addLead(
                  Lead(
                    id: 'l${DateTime.now().microsecondsSinceEpoch}',
                    name: name.text.trim(),
                    phone: phone.text.trim(),
                    status: LeadStatus.newLead,
                    createdAt: DateTime.now(),
                    collaboratorResponsibleId: id,
                  ),
                );
            Navigator.pop(dialogContext);
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  name.dispose();
  phone.dispose();
}

void _mine(BuildContext c, WidgetRef ref, String id) {
  final b = ref
      .read(operationsProvider)
      .bookings
      .where((x) => x.collaboratorResponsibleId == id);
  showModalBottomSheet(
    context: c,
    builder: (_) => ListView(
      children: [
        for (final x in b)
          ListTile(
            title: Text(x.status.name),
            subtitle: Text('${x.startsAt.day}/${x.startsAt.month}'),
          ),
      ],
    ),
  );
}

void _activity(BuildContext c, WidgetRef ref, String id) {
  final s = ref.read(operationsProvider);
  final leads = s.leads.where((x) => x.collaboratorResponsibleId == id).length;
  final b = s.bookings.where((x) => x.collaboratorResponsibleId == id).length;
  final r = s.receipts.where((x) => x.recordedByCollaboratorId == id).length;
  showModalBottomSheet(
    context: c,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        'Leads: $leads\nMarcações: $b\nRecebimentos: $r\nTotal de ações: ${leads + b + r}',
      ),
    ),
  );
}
