import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../operations/operations_controller.dart';
import 'empresa_sync_service.dart';

/// Se a empresa já existe no servidor, traz a ficha em vez de perguntar tudo
/// outra vez.
///
/// O caso que isto resolve: trocar de telemóvel, ou reinstalar. Os dados estão
/// no servidor, a sessão está iniciada, o RLS deixa lê-los — e mesmo assim a
/// app abria o onboarding a perguntar «Como te chamas?». A ficha só viajava num
/// sentido: a app empurrava-a e nunca a lia de volta.
///
/// Corre uma vez, e só quando não há nada local: quem já tem a empresa
/// preenchida neste telemóvel manda nela, e não é o servidor que lhe passa por
/// cima do que tem à frente.
final fichaRecebidaProvider = FutureProvider<bool>((ref) async {
  final operacoes = ref.read(operationsProvider.notifier);
  if (ref.read(operationsProvider).onboarded) return false;

  final servico = ref.read(empresaSyncProvider);
  if (servico == null) return false;

  final ficha = await servico.buscarFicha();
  if (ficha == null) return false;

  ficha.aplicarEm(operacoes);
  return true;
});
