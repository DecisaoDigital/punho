import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/operations/operations_controller.dart';
import '../../../domain/models/operations.dart';

/// **A caixa das leads quentes** (César, 11 Out 2026): pessoas que nunca foram
/// clientes e chegaram pelo funil, pelo Carlitos ou à mão. Só o gerente e a
/// administrativa as veem e as tratam; o bot capta mas nunca valida.
///
/// Cada cartão traz o que o humano precisa para decidir a chamada: a zona (vem
/// ao escritório ou vamos lá), o negócio, quão completa está a ficha e há
/// quanto tempo espera. Um toque para ligar, um para «Falei», um para validar.
class LeadsQuentesSecao extends ConsumerWidget {
  const LeadsQuentesSecao({super.key, this.validadoPor = 'gestor'});

  /// Quem está a validar (id do colaborador, ou «gestor»).
  final String validadoPor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agora = DateTime.now();
    final estado = ref.watch(operationsProvider);
    final maquinas = estado.machines;
    final quentes = estado.leads.where((l) => l.quente).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (quentes.isEmpty) return const SizedBox.shrink();
    final n = ref.read(operationsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            'Leads quentes · ${quentes.length} por validar',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        for (final l in quentes)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.negocio.isEmpty ? l.name : '${l.name} · ${l.negocio}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      l.phone,
                      if (l.temZona)
                        [
                          l.codigoPostal,
                          l.localidade,
                        ].where((v) => v.trim().isNotEmpty).join(' ')
                      else
                        'sem zona',
                      'ficha ${l.fichaCompleta}/6',
                      esperaDaLead(l.createdAt, agora),
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (pedidoDaLead(l, maquinas) case final pedido?)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        pedido,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () =>
                            launchUrl(Uri(scheme: 'tel', path: l.phone)),
                        icon: const Icon(Icons.call, size: 18),
                        label: const Text('Ligar'),
                      ),
                      OutlinedButton(
                        onPressed: () => n.registarContacto(l.id, 'tel'),
                        child: const Text('Falei'),
                      ),
                      FilledButton(
                        onPressed: () => n.validarLead(l.id, validadoPor),
                        child: const Text('Validar'),
                      ),
                      PopupMenuButton<MotivoDePerda>(
                        tooltip: 'Perdida',
                        onSelected: (m) => n.perderLead(l.id, m),
                        itemBuilder: (_) => [
                          for (final m in MotivoDePerda.values)
                            PopupMenuItem(
                              value: m,
                              child: Text(motivoDePerdaLabel(m)),
                            ),
                        ],
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Perdida'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// «há 20 min», «há 3 h», «há 2 dias»: quanto a lead espera por um humano.
String esperaDaLead(DateTime criada, DateTime agora) {
  final d = agora.difference(criada);
  if (d.inMinutes < 1) return 'agora';
  if (d.inHours < 1) return 'há ${d.inMinutes} min';
  if (d.inDays < 1) return 'há ${d.inHours} h';
  return 'há ${d.inDays} ${d.inDays == 1 ? 'dia' : 'dias'}';
}

/// Os dias de aluguer pedidos não existem em nenhuma tabela de preços das
/// máquinas ativas. Sem tabelas nenhuma não se pode dizer que está fora.
bool periodoForaDaTabela(Lead l, List<Machine> maquinas) {
  final dias = l.periodoDias;
  if (l.tipo != LeadTipo.aluguer || dias == null) return false;
  final tabelados = {
    for (final m in maquinas.where((m) => !m.archived))
      for (final t in m.tarifas) t.dias,
  };
  return tabelados.isNotEmpty && !tabelados.contains(dias);
}

/// A linha «o que quer»: tipo, período e dia pedido, e a quem cabe.
/// Venda e aluguer fora da tabela não têm escala: ficam com o gerente.
String? pedidoDaLead(Lead l, List<Machine> maquinas) {
  final tipo = l.tipo;
  if (tipo == null) return l.categoria.isEmpty ? null : l.categoria;
  String dh(DateTime d) {
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)} às ${dois(d.hour)}:${dois(d.minute)}';
  }

  final fora = periodoForaDaTabela(l, maquinas);
  final partes = <String>[
    if (l.categoria.isNotEmpty) l.categoria else 'sem categoria',
    leadTipoLabel(tipo),
    if (l.periodoDias != null) '${l.periodoDias} dias',
    if (fora) 'fora da tabela de preços',
    if (l.horarioPedido != null && !fora && tipo != LeadTipo.venda)
      (tipo == LeadTipo.aluguer ? 'entrega ' : 'pede ') + dh(l.horarioPedido!),
    if (tipo == LeadTipo.venda || fora) 'ver com o gerente',
  ];
  return partes.join(' · ');
}
