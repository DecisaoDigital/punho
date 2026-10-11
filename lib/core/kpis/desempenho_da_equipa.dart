import '../../domain/models/operations.dart';
import '../operations/operations_controller.dart';

/// O que cada colaborador fez no mês: dinheiro cobrado e contactos angariados.
class DesempenhoDoColaborador {
  const DesempenhoDoColaborador(
    this.id,
    this.nome, {
    this.cobradoCents = 0,
    this.contactos = 0,
    this.clientes = 0,
  });

  final String id, nome;

  /// Recebimentos que registou no mês.
  final int cobradoCents;

  /// Contactos criados no mês e atribuídos a ele (prospecção, balcão, telefone).
  final int contactos;

  /// Desses contactos, quantos já são clientes.
  final int clientes;
}

/// **Quem fez o quê no mês** (César, 11 Out 2026): o recebimento guarda quem o
/// registou e o contacto guarda o responsável, por isso a equipa pode ver-se
/// pelo que cobra e pelo que angaria — a colega do escritório que descobre um
/// cliente fica com ele no nome.
class DesempenhoDaEquipa {
  const DesempenhoDaEquipa(this.colaboradores);

  /// Só quem tem algo no mês.
  final List<DesempenhoDoColaborador> colaboradores;

  int get cobradoCents => colaboradores.fold(0, (s, c) => s + c.cobradoCents);

  List<DesempenhoDoColaborador> get porCobrado =>
      colaboradores.where((c) => c.cobradoCents > 0).toList()
        ..sort((a, b) => b.cobradoCents.compareTo(a.cobradoCents));

  List<DesempenhoDoColaborador> get porAngariado =>
      colaboradores.where((c) => c.contactos > 0).toList()..sort((a, b) {
        final porContactos = b.contactos.compareTo(a.contactos);
        return porContactos != 0
            ? porContactos
            : b.clientes.compareTo(a.clientes);
      });

  DesempenhoDoColaborador? get quemMaisCobrou =>
      porCobrado.isEmpty ? null : porCobrado.first;

  DesempenhoDoColaborador? get quemMaisAngariou =>
      porAngariado.isEmpty ? null : porAngariado.first;

  /// Média cobrada por quem cobrou; `null` sem ninguém.
  int? get mediaCobradaCents {
    final quem = porCobrado;
    return quem.isEmpty ? null : cobradoCents ~/ quem.length;
  }
}

DesempenhoDaEquipa desempenhoDaEquipa(OperationsState state, DateTime mes) {
  final nomes = {for (final c in state.collaborators) c.id: c.name};
  final cobrado = <String, int>{};
  for (final r in state.receipts) {
    final quem = r.recordedByCollaboratorId;
    if (quem == null || r.archived || r.amountCents <= 0) continue;
    if (r.date.year != mes.year || r.date.month != mes.month) continue;
    cobrado[quem] = (cobrado[quem] ?? 0) + r.amountCents;
  }
  final contactos = <String, int>{};
  final clientes = <String, int>{};
  for (final l in state.leads) {
    final quem = l.collaboratorResponsibleId;
    if (quem == null) continue;
    if (l.createdAt.year != mes.year || l.createdAt.month != mes.month) {
      continue;
    }
    contactos[quem] = (contactos[quem] ?? 0) + 1;
    if (l.status == LeadStatus.converted || l.convertedCustomerId != null) {
      clientes[quem] = (clientes[quem] ?? 0) + 1;
    }
  }
  final ids = {...cobrado.keys, ...contactos.keys};
  return DesempenhoDaEquipa([
    for (final id in ids)
      DesempenhoDoColaborador(
        id,
        nomes[id] ?? 'Colaborador removido',
        cobradoCents: cobrado[id] ?? 0,
        contactos: contactos[id] ?? 0,
        clientes: clientes[id] ?? 0,
      ),
  ]);
}
