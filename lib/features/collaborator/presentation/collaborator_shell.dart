import 'package:flutter/material.dart';

import '../../../core/layout/ecra_de_formulario.dart';
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
        // ListView e não Column: cinco botões de 76 dp não cabem numa janela
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
            // Despesa/fatura não é do operador: o servidor recusa-a (RLS, 42501)
            // e um botão que o servidor recusa não devia existir. Fica no gestor.
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

Future<void> _newLead(BuildContext c, WidgetRef ref, String id) async {
  final name = TextEditingController();
  final phone = TextEditingController();
  await abrirFormulario<void>(
    c,
    (rota) => _FormularioDeLeadDoColaborador(
      nome: name,
      telemovel: phone,
      colaboradorId: id,
      ref: ref,
    ),
  );
  name.dispose();
  phone.dispose();
}

/// A mesma lead da app do gestor, com o colaborador já preenchido como
/// responsável.
class _FormularioDeLeadDoColaborador extends StatefulWidget {
  const _FormularioDeLeadDoColaborador({
    required this.nome,
    required this.telemovel,
    required this.colaboradorId,
    required this.ref,
  });

  final TextEditingController nome;
  final TextEditingController telemovel;
  final String colaboradorId;
  final WidgetRef ref;

  @override
  State<_FormularioDeLeadDoColaborador> createState() =>
      _FormularioDeLeadDoColaboradorState();
}

class _FormularioDeLeadDoColaboradorState
    extends State<_FormularioDeLeadDoColaborador> {
  String? erro;

  @override
  Widget build(BuildContext context) => EcraDeFormulario(
    titulo: 'Nova lead',
    aviso: erro,
    campos: [
      CampoDeTexto(
        controlador: widget.nome,
        rotulo: 'Nome',
        autofocus: true,
        capitalizacao: TextCapitalization.words,
      ),
      CampoDeTexto(
        controlador: widget.telemovel,
        rotulo: 'Telemóvel',
        teclado: TextInputType.phone,
      ),
    ],
    aoGuardar: () {
      // Antes o botão não fazia nada quando faltava um dos dois, e não dizia
      // porquê — ficava-se a carregar sem perceber.
      if (widget.nome.text.trim().isEmpty ||
          widget.telemovel.text.trim().isEmpty) {
        setState(() => erro = 'A lead precisa do nome e do telemóvel.');
        return;
      }
      widget.ref
          .read(operationsProvider.notifier)
          .addLead(
            Lead(
              id: 'l${DateTime.now().microsecondsSinceEpoch}',
              name: widget.nome.text.trim(),
              phone: widget.telemovel.text.trim(),
              status: LeadStatus.newLead,
              createdAt: DateTime.now(),
              collaboratorResponsibleId: widget.colaboradorId,
            ),
          );
      Navigator.pop(context);
    },
  );
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
