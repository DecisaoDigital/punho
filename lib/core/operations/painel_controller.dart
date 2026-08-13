import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/operation_repository.dart';
import '../../domain/models/arranjo_do_painel.dart';
import 'operations_controller.dart';

/// **Quem manda no painel é o gestor.**
///
/// Fica fora do `OperationsState` de propósito. Aquilo é o estado da empresa —
/// máquinas, reservas, dinheiro — e é lido por meia app; isto é uma preferência
/// de quem está a olhar. Metê-la lá dentro fazia todo o ecrã que observa
/// operações reconstruir-se de cada vez que ele marcasse uma caixa.
///
/// Vive no `core` e não na pasta do painel porque não é coisa de apresentação:
/// é estado guardado no repositório, e quem sincroniza tem de lhe poder tocar
/// sem que o `core` passe a depender de um ecrã.
class PainelController extends Notifier<ArranjoDoPainel> {
  OperationRepository get _repo => ref.read(operationRepositoryProvider);

  @override
  ArranjoDoPainel build() => _repo.painel;

  void alternar(String id, {required bool escolher}) =>
      _guardar(_actual.comEscolha(id, escolher: escolher));

  void reordenar(Iterable<String> ordem) => _guardar(_actual.comOrdem(ordem));

  /// Aceita a sugestão da bancada: [id] sobe ao painel e fica ao lado do
  /// número que o motivou. Ver `features/kpis/domain/sugestao_do_painel.dart`.
  void porNoPainelJuntoDe(String id, {required String depoisDe}) =>
      _guardar(_actual.comEscolhaJuntoDe(id, depoisDe: depoisDe));

  /// O que está **gravado**, e não o que este controlador tem em memória.
  ///
  /// A diferença não é teórica: o instantâneo do servidor escreve o painel
  /// directamente no repositório. Compor a alteração a partir do que estava em
  /// memória pegava numa fotografia velha e mandava-a de volta para cima da
  /// boa — marcar uma caixa apagava, sem erro nenhum, o painel que ele tinha
  /// composto no outro aparelho.
  ArranjoDoPainel get _actual => _repo.painel;

  /// Relê o que está gravado. Chamado depois de a sincronização trazer um
  /// instantâneo — os dados já lá estão, falta o ecrã dar por isso.
  void recarregarDoRepositorio() => state = _repo.painel;

  void _guardar(ArranjoDoPainel novo) {
    _repo.savePainel(novo);
    state = novo;
  }
}

final painelProvider = NotifierProvider<PainelController, ArranjoDoPainel>(
  PainelController.new,
);
