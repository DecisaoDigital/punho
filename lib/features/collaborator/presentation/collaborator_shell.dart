import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../core/layout/phone_orientation_lock.dart';
import '../../../core/session/demo_session.dart';
import '../../../domain/models/operations.dart';
import '../../finance/presentation/finance_pages.dart';
import '../../operations/presentation/operational_pages.dart';

class CollaboratorShell extends ConsumerWidget {
  const CollaboratorShell({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(demoSessionProvider);
    final id = session.collaboratorId!;
    return PhoneOrientationLock(
      orientation: PhoneOrientation.portrait,
      child: Scaffold(
        appBar: AppBar(title: Text(session.label)),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
        ),
      ),
    );
  }
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
  showBookingForm(c, ref, responsibleId: id);
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
