import '../../domain/models/operations.dart';

/// Um alarme que tem de existir neste aparelho.
class LembreteAgendado {
  const LembreteAgendado({
    required this.reuniaoId,
    required this.idNotificacao,
    required this.quando,
    required this.texto,
  });

  final String reuniaoId;

  /// Inteiro de 31 bits, estável para a mesma reunião: é o que permite
  /// cancelar e reagendar sem deixar alarmes órfãos.
  final int idNotificacao;
  final DateTime quando;
  final String texto;

  @override
  bool operator ==(Object other) =>
      other is LembreteAgendado &&
      other.reuniaoId == reuniaoId &&
      other.quando == quando &&
      other.texto == texto;

  @override
  int get hashCode => Object.hash(reuniaoId, quando, texto);
}

const janelaDeLembretes = Duration(days: 30);
const maximoDeLembretes = 50;

/// FNV-1a de 32 bits reduzido a 31: sem `String.hashCode`, que não é estável
/// entre execuções.
int idDeNotificacao(String reuniaoId) {
  var h = 0x811c9dc5;
  for (final c in reuniaoId.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
  }
  final id = h & 0x7FFFFFFF;
  return id == 0 ? 1 : id;
}

/// O que deve estar agendado agora, e só isso.
///
/// Função pura: quem chama compara com o que já está agendado, ou, mais
/// simples, cancela tudo e agenda isto. Só entra uma reunião que seja:
/// reunião, não cancelada, **criada por [uidActual]** (o alarme toca em quem a
/// marcou, não em quem a vê), com aviso escolhido e cujo instante ainda não
/// passou nem está para lá da janela.
List<LembreteAgendado> reconciliar(
  Iterable<Booking> reunioes,
  String? uidActual,
  DateTime agora,
) {
  if (uidActual == null) return const [];
  final limite = agora.add(janelaDeLembretes);
  final plano = <LembreteAgendado>[];
  for (final r in reunioes) {
    if (!r.eReuniao) continue;
    if (r.status == BookingStatus.cancelled) continue;
    if (r.criadoPorUid != uidActual) continue;
    final antes = r.lembreteMinutos;
    if (antes == null) continue;
    final quando = r.startsAt.subtract(Duration(minutes: antes));
    if (!quando.isAfter(agora) || quando.isAfter(limite)) continue;
    final hh = r.startsAt.hour.toString().padLeft(2, '0');
    final mm = r.startsAt.minute.toString().padLeft(2, '0');
    final nome = r.customerNameSnapshot.trim();
    plano.add(
      LembreteAgendado(
        reuniaoId: r.id,
        idNotificacao: idDeNotificacao(r.id),
        quando: quando,
        // Sem notas nem NIF: isto aparece no ecrã bloqueado.
        texto: nome.isEmpty
            ? 'Reunião às $hh:$mm'
            : 'Reunião às $hh:$mm com $nome',
      ),
    );
  }
  plano.sort((a, b) => a.quando.compareTo(b.quando));
  return plano.take(maximoDeLembretes).toList();
}
