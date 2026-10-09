import 'reconciliar.dart';

/// O que o aparelho nos deixa fazer em matéria de avisos.
class PermissoesDoAlarme {
  const PermissoesDoAlarme({required this.notificacoes, required this.exacto});

  /// Pode mostrar notificações.
  final bool notificacoes;

  /// Pode tocar à hora certa (Android 12+: «Alarmes e lembretes»).
  final bool exacto;

  bool get tudo => notificacoes && exacto;

  static const todas = PermissoesDoAlarme(notificacoes: true, exacto: true);
}

/// Quem põe os alarmes no aparelho. Existe como interface para o resto da app
/// e os testes não saberem se há Android por baixo.
abstract class AgendadorDeLembretes {
  /// Deixa agendado exactamente [plano]: o que lá estava e já não consta é
  /// cancelado.
  Future<void> aplicar(List<LembreteAgendado> plano);

  Future<void> cancelarTudo();

  Future<PermissoesDoAlarme> permissoes();

  /// Pede o que falta. Pode abrir um ecrã do sistema.
  Future<PermissoesDoAlarme> pedirPermissoes();

  /// Dispara daqui a [segundos] um aviso de teste.
  Future<void> testar({int segundos = 60});
}

/// Sem alarmes: Windows, e quem corre sem plugin.
class AgendadorNulo implements AgendadorDeLembretes {
  const AgendadorNulo();
  @override
  Future<void> aplicar(List<LembreteAgendado> plano) async {}
  @override
  Future<void> cancelarTudo() async {}
  @override
  Future<PermissoesDoAlarme> permissoes() async => PermissoesDoAlarme.todas;
  @override
  Future<PermissoesDoAlarme> pedirPermissoes() async =>
      PermissoesDoAlarme.todas;
  @override
  Future<void> testar({int segundos = 60}) async {}
}

/// Para testes: guarda o que lhe pedem.
class AgendadorFalso implements AgendadorDeLembretes {
  List<LembreteAgendado> agendados = const [];
  int cancelamentos = 0;
  int pedidosDePermissao = 0;
  int testes = 0;
  PermissoesDoAlarme estado = PermissoesDoAlarme.todas;

  @override
  Future<void> aplicar(List<LembreteAgendado> plano) async =>
      agendados = List.of(plano);
  @override
  Future<void> cancelarTudo() async {
    cancelamentos++;
    agendados = const [];
  }

  @override
  Future<PermissoesDoAlarme> permissoes() async => estado;
  @override
  Future<PermissoesDoAlarme> pedirPermissoes() async {
    pedidosDePermissao++;
    return estado;
  }

  @override
  Future<void> testar({int segundos = 60}) async => testes++;
}
