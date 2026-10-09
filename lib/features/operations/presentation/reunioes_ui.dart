import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/layout/ecra_de_formulario.dart';
import '../../../core/lembretes/agendador.dart';
import '../../../core/lembretes/lembretes_providers.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../domain/models/operations.dart';
import '../../auth/acesso_providers.dart';

/// Antecedências que o utilizador pode escolher. `null` = sem aviso.
const antecedenciasDoLembrete = <int?>[10, 15, 30, null];

String rotuloDaAntecedencia(int? minutos) =>
    minutos == null ? 'Sem aviso' : '$minutos min antes';

const _chaveDoUltimoLembrete = 'reuniao_ultimo_lembrete_minutos';

Future<int?> _ultimoLembrete() async {
  try {
    final p = await SharedPreferences.getInstance();
    final v = p.getInt(_chaveDoUltimoLembrete);
    if (v == null) return 15;
    return v < 0 ? null : v;
  } catch (_) {
    return 15;
  }
}

Future<void> _guardarUltimoLembrete(int? minutos) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_chaveDoUltimoLembrete, minutos ?? -1);
  } catch (_) {}
}

String? _uidDoUtilizador(WidgetRef ref) {
  try {
    return ref.read(acessoServiceProvider).utilizadorId;
  } catch (_) {
    return null;
  }
}

String _doisDigitos(int n) => n.toString().padLeft(2, '0');

String rotuloDaReuniao(Booking r) {
  const dias = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
  final d = r.startsAt;
  return '${dias[d.weekday - 1]} ${d.day}/${d.month} '
      '${_doisDigitos(d.hour)}:${_doisDigitos(d.minute)}';
}

Future<void> abrirReuniao(BuildContext context, {Booking? existente}) =>
    abrirFormulario<void>(
      context,
      (_) => FormularioDeReuniao(existente: existente),
    );

/// Nova reunião (ou remarcação de uma existente): cliente, dia, hora, aviso.
/// A duração é fixa e não se pergunta.
class FormularioDeReuniao extends ConsumerStatefulWidget {
  const FormularioDeReuniao({super.key, this.existente});

  final Booking? existente;

  @override
  ConsumerState<FormularioDeReuniao> createState() =>
      _FormularioDeReuniaoState();
}

class _FormularioDeReuniaoState extends ConsumerState<FormularioDeReuniao> {
  String? clienteId;
  late DateTime dia;
  late TimeOfDay hora;
  int? lembrete = 15;
  final notas = TextEditingController();
  String? erro;

  @override
  void initState() {
    super.initState();
    final e = widget.existente;
    final agora = ref.read(relogioProvider)();
    if (e != null) {
      clienteId = e.customerId;
      dia = DateUtils.dateOnly(e.startsAt);
      hora = TimeOfDay.fromDateTime(e.startsAt);
      lembrete = e.lembreteMinutos;
      notas.text = e.notes;
    } else {
      final proxima = DateTime(
        agora.year,
        agora.month,
        agora.day,
        agora.hour + 1,
      );
      dia = DateUtils.dateOnly(proxima);
      hora = TimeOfDay(hour: proxima.hour, minute: 0);
      _ultimoLembrete().then((v) {
        if (mounted) setState(() => lembrete = v);
      });
    }
  }

  @override
  void dispose() {
    notas.dispose();
    super.dispose();
  }

  DateTime get _inicio =>
      DateTime(dia.year, dia.month, dia.day, hora.hour, hora.minute);

  @override
  Widget build(BuildContext context) {
    final clientes = ref
        .watch(operationsProvider)
        .customers
        .where((c) => !c.archived)
        .toList();
    final editar = widget.existente != null;
    return EcraDeFormulario(
      titulo: editar ? 'Remarcar reunião' : 'Nova reunião',
      rotuloGuardar: editar ? 'Guardar' : 'Marcar reunião',
      aviso: erro,
      campos: [
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: clienteId,
          decoration: const InputDecoration(
            labelText: 'Cliente *',
            hintText: 'Com quem é a reunião',
          ),
          items: [
            for (final c in clientes)
              DropdownMenuItem(value: c.id, child: Text(c.name)),
          ],
          onChanged: editar ? null : (v) => setState(() => clienteId = v),
        ),
        CampoLargo(
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Dia'),
            subtitle: Text('${dia.day}/${dia.month}/${dia.year}'),
            trailing: const Icon(Icons.event_outlined),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 730)),
                initialDate: dia,
              );
              if (d != null) setState(() => dia = DateUtils.dateOnly(d));
            },
          ),
        ),
        CampoLargo(
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hora'),
            subtitle: Text(
              '${_doisDigitos(hora.hour)}:${_doisDigitos(hora.minute)}',
            ),
            trailing: const Icon(Icons.schedule_outlined),
            onTap: () async {
              final h = await showTimePicker(
                context: context,
                initialTime: hora,
              );
              if (h != null) setState(() => hora = h);
            },
          ),
        ),
        DropdownButtonFormField<int?>(
          isExpanded: true,
          initialValue: lembrete,
          key: ValueKey(lembrete),
          decoration: const InputDecoration(labelText: 'Avisar-me'),
          items: [
            for (final m in antecedenciasDoLembrete)
              DropdownMenuItem(value: m, child: Text(rotuloDaAntecedencia(m))),
          ],
          onChanged: (v) => setState(() => lembrete = v),
        ),
        if (lembrete != null) const CampoLargo(CartaoDoAlarme()),
        CampoDeTexto(
          controlador: notas,
          rotulo: 'Notas',
          capitalizacao: TextCapitalization.sentences,
        ),
      ],
      aoGuardar: () {
        if (clienteId == null) {
          setState(() => erro = 'Escolhe o cliente da reunião.');
          return;
        }
        final notifier = ref.read(operationsProvider.notifier);
        final e = widget.existente;
        if (e != null) {
          notifier.remarcarReuniao(e.id, _inicio, lembreteMinutos: lembrete);
        } else {
          if (!_inicio.isAfter(ref.read(relogioProvider)())) {
            setState(() => erro = 'Escolhe uma hora que ainda não passou.');
            return;
          }
          notifier.agendarReuniao(
            customerId: clienteId!,
            inicio: _inicio,
            lembreteMinutos: lembrete,
            notes: notas.text.trim(),
            criadoPorUid: _uidDoUtilizador(ref),
          );
          _guardarUltimoLembrete(lembrete);
          if (lembrete != null) {
            // Só aqui, na 1.ª reunião com aviso: nunca no arranque.
            final agendador = ref.read(agendadorProvider);
            agendador.pedirPermissoes();
          }
        }
        Navigator.pop(context);
      },
    );
  }
}

/// Faixa com as reuniões que ainda vêm aí. Desaparece quando não há nenhuma,
/// para não gastar altura ao calendário.
class FaixaDeReunioes extends ConsumerWidget {
  const FaixaDeReunioes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agora = ref.watch(relogioProvider)();
    final proximas =
        ref
            .watch(operationsProvider)
            .reunioes
            .where((r) => r.status != BookingStatus.cancelled)
            .where((r) => r.endsAt.isAfter(agora))
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    if (proximas.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: proximas.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final r = proximas[i];
          return ActionChip(
            avatar: Icon(
              r.lembreteMinutos == null
                  ? Icons.groups_outlined
                  : Icons.alarm_outlined,
              size: 18,
            ),
            label: Text('${r.customerNameSnapshot} · ${rotuloDaReuniao(r)}'),
            onPressed: () => _menuDaReuniao(context, ref, r),
          );
        },
      ),
    );
  }

  Future<void> _menuDaReuniao(
    BuildContext context,
    WidgetRef ref,
    Booking r,
  ) async {
    final acao = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Reunião com ${r.customerNameSnapshot}'),
              subtitle: Text(rotuloDaReuniao(r)),
            ),
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: const Text('Remarcar'),
              onTap: () => Navigator.pop(context, 'remarcar'),
            ),
            ListTile(
              leading: const Icon(Icons.event_busy_outlined),
              title: const Text('Cancelar reunião'),
              onTap: () => Navigator.pop(context, 'cancelar'),
            ),
          ],
        ),
      ),
    );
    if (acao == 'remarcar' && context.mounted) {
      await abrirReuniao(context, existente: r);
    } else if (acao == 'cancelar') {
      ref.read(operationsProvider.notifier).cancelarReuniao(r.id);
    }
  }
}

/// Diz se o alarme vai mesmo tocar neste telemóvel, e deixa experimentar.
class CartaoDoAlarme extends ConsumerStatefulWidget {
  const CartaoDoAlarme({super.key});

  @override
  ConsumerState<CartaoDoAlarme> createState() => _CartaoDoAlarmeState();
}

class _CartaoDoAlarmeState extends ConsumerState<CartaoDoAlarme> {
  PermissoesDoAlarme? _permissoes;
  bool _testeAgendado = false;

  @override
  void initState() {
    super.initState();
    _ler();
  }

  Future<void> _ler() async {
    try {
      final p = await ref.read(agendadorProvider).permissoes();
      if (mounted) setState(() => _permissoes = p);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final p = _permissoes;
    final tema = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'O aviso toca neste telemóvel, depois de ele sincronizar a reunião.',
          style: tema.bodySmall,
        ),
        if (p != null && !p.tudo) ...[
          const SizedBox(height: 4),
          Text(
            p.notificacoes
                ? 'Falta autorizar «Alarmes e lembretes» para tocar à hora certa.'
                : 'Falta autorizar as notificações para o aviso aparecer.',
            style: tema.bodySmall?.copyWith(color: Colors.red.shade700),
          ),
        ],
        Wrap(
          spacing: 8,
          children: [
            if (p != null && !p.tudo)
              TextButton(
                onPressed: () async {
                  final novo = await ref
                      .read(agendadorProvider)
                      .pedirPermissoes();
                  if (mounted) setState(() => _permissoes = novo);
                },
                child: const Text('Autorizar'),
              ),
            TextButton(
              onPressed: () async {
                await ref.read(agendadorProvider).pedirPermissoes();
                await ref.read(agendadorProvider).testar();
                if (mounted) setState(() => _testeAgendado = true);
              },
              child: Text(
                _testeAgendado
                    ? 'Teste marcado para daqui a 1 min'
                    : 'Testar alarme (daqui a 1 min)',
              ),
            ),
            TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const _AjudaDoAlarme(),
              ),
              child: const Text('Não tocou?'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AjudaDoAlarme extends StatelessWidget {
  const _AjudaDoAlarme();

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Para o alarme tocar sempre'),
    content: const SingleChildScrollView(
      child: Text(
        'Alguns telemóveis (Xiaomi/MIUI, Samsung, Huawei, Oppo) adormecem as '
        'apps para poupar bateria e o aviso pode falhar. Faz uma vez:\n\n'
        '1. Definições › Apps › Fist › Poupança de bateria › «Sem restrições».\n'
        '2. Definições › Apps › Fist › «Arranque automático» ligado '
        '(Xiaomi).\n'
        '3. Definições › Apps › Fist › Notificações › permitir, e '
        '«Alarmes e lembretes» ligado.\n'
        '4. Nas apps recentes, mantém o Fist e carrega no cadeado '
        '(não o feches a deslizar).\n\n'
        'Depois carrega em «Testar alarme» e bloqueia o ecrã: tem de tocar '
        'ao fim de 1 minuto.',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Fechar'),
      ),
    ],
  );
}
