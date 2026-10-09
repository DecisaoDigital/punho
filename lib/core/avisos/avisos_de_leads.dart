import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/operations.dart';
import '../operations/operations_controller.dart';

/// Chave do `ScaffoldMessenger` da app inteira: permite mostrar um aviso a
/// partir de cima de qualquer ecrã.
final mensageiroGlobal = GlobalKey<ScaffoldMessengerState>();

/// Quais das [agora] são novidade em relação a [antes] e não foram escritas
/// neste aparelho. Função pura; [antes] `null` é a primeira carga, que nunca
/// avisa (senão cada arranque anunciava a lista toda).
List<Lead> leadsNovas({
  required List<Lead>? antes,
  required List<Lead> agora,
  required Set<String> criadasAqui,
  int maximoDeUmaVez = 10,
}) {
  if (antes == null) return const [];
  final conhecidas = {for (final l in antes) l.id};
  final novas = [
    for (final l in agora)
      if (!conhecidas.contains(l.id) && !criadasAqui.contains(l.id)) l,
  ];
  // Uma carga em bloco (primeiro sync, restauro) não é «lead nova».
  return novas.length > maximoDeUmaVez ? const [] : novas;
}

String textoDoAvisoDeLeads(List<Lead> novas) => novas.length == 1
    ? 'Lead nova: ${novas.single.name}'
    : '${novas.length} leads novas';

/// Avisa, com a app aberta, quando chega uma lead que outro aparelho ou o
/// servidor criaram (site, bot, outro operador). É a camada 1 do aviso; com a
/// app fechada será o push (camada 2, à espera do projecto Firebase do Punho).
class ObservadorDeLeadsNovas extends ConsumerStatefulWidget {
  const ObservadorDeLeadsNovas({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ObservadorDeLeadsNovas> createState() => _State();
}

class _State extends ConsumerState<ObservadorDeLeadsNovas> {
  List<Lead>? _antes;

  /// Nos primeiros segundos a lista ainda está a chegar do servidor: isso é
  /// carga inicial, não novidade.
  final _aquecimentoAte = DateTime.now().add(const Duration(seconds: 5));

  @override
  void initState() {
    super.initState();
    // A primeira leitura fica como ponto de partida, sem avisar.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _antes = ref.read(operationsProvider).leads,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(operationsProvider.select((s) => s.leads), (_, agora) {
      final criadas = ref.read(operationsProvider.notifier).leadsCriadasAqui;
      final novas = leadsNovas(
        antes: _antes,
        agora: agora,
        criadasAqui: criadas,
      );
      _antes = agora;
      if (novas.isEmpty || DateTime.now().isBefore(_aquecimentoAte)) return;
      mensageiroGlobal.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(textoDoAvisoDeLeads(novas)),
            duration: const Duration(seconds: 8),
          ),
        );
    });
    return widget.child;
  }
}
