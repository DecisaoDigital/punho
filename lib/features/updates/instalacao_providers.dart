import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/orientacao/orientacao_do_contexto.dart';
import '../../core/updates/instalador_de_update.dart';
import '../../core/updates/update_info.dart';
import 'update_providers.dart';

final instaladorProvider = Provider<InstaladorDeUpdate>(
  (_) => InstaladorDeUpdate(),
);

/// Trata da actualização do princípio ao fim: descarrega em segundo plano,
/// verifica e instala.
///
/// O objectivo, nas palavras do Cesar: *"aceita-se receber o update e depois
/// continuamos a trabalhar"*. O download é a parte que demorava e obrigava a
/// sair da app — é ele que passa a acontecer sozinho, sem interromper nada.
///
/// A instalação é que não pode ser totalmente silenciosa: o Android só a
/// dispensa de confirmação a partir do 12, e mesmo aí só quando foi o próprio
/// Punho a instalar a versão anterior. Da segunda actualização em diante deixa
/// de haver toque nenhum.
final estadoDoUpdateProvider =
    NotifierProvider<InstalacaoController, EstadoDoUpdate>(
      InstalacaoController.new,
    );

class InstalacaoController extends Notifier<EstadoDoUpdate> {
  bool _vivo = true;

  /// Verdadeiro enquanto o retrato estiver imposto por causa desta sequência
  /// (pedido de permissão + instalação). Existe para o regresso à app saber
  /// se há alguma coisa para largar — sem isto, um regresso normal (o gestor
  /// só alternou de app) largaria uma sobreposição que nunca pediu.
  bool _aSegurarRetrato = false;
  _ObservadorDeRegressoDoInstalador? _observador;

  @override
  EstadoDoUpdate build() {
    // Uma versão nova a aparecer arranca a descarga por si. Só isso, e só se o
    // ficheiro puder ser verificado.
    ref.listen<PunhoUpdateInfo?>(punhoUpdateProvider, (anterior, actual) {
      if (actual == null) return;
      if (anterior?.buildNumber == actual.buildNumber) return;
      if ((actual.sha256 ?? '').isEmpty) return;
      unawaited(descarregar(actual));
    });
    _observador = _ObservadorDeRegressoDoInstalador(() {
      if (!_vivo || !_aSegurarRetrato) return;
      // Voltar à app enquanto se segurava o retrato só acontece quando o
      // gestor recusou a permissão, saiu do instalador sem decidir, ou o
      // Play Protect terminou o scan sem instalar nada — uma instalação que
      // corre até ao fim mata o processo. Devolve a orientação que o ecrã de
      // baixo pedia; se tinha ficado a meio da instalação, deixa tentar
      // outra vez.
      unawaited(_libertarRetrato());
      if (state.fase == FaseDoUpdate.aInstalar ||
          state.fase == FaseDoUpdate.aguardaConfirmacao) {
        state = EstadoDoUpdate(
          fase: FaseDoUpdate.pronta,
          caminho: state.caminho,
        );
      }
    });
    WidgetsBinding.instance.addObserver(_observador!);
    ref.onDispose(() {
      _vivo = false;
      if (_observador != null) {
        WidgetsBinding.instance.removeObserver(_observador!);
      }
    });
    return const EstadoDoUpdate(fase: FaseDoUpdate.disponivel);
  }

  Future<void> descarregar(PunhoUpdateInfo info) async {
    if (state.fase == FaseDoUpdate.aDescarregar) return;
    // Só em Wi-Fi por defeito: são 76 MB, e gastá-los nos dados móveis dele sem
    // avisar é abusar da confiança. Quem quiser força pelo botão.
    if (!await _emWifi()) {
      debugPrint('[Instalador] sem Wi-Fi — descarga adiada');
      return;
    }
    await _descarregar(info);
  }

  /// Descarrega mesmo sem Wi-Fi, porque foi ele a pedir.
  Future<void> descarregarAgora(PunhoUpdateInfo info) => _descarregar(info);

  Future<void> _descarregar(PunhoUpdateInfo info) async {
    state = const EstadoDoUpdate(fase: FaseDoUpdate.aDescarregar);
    final caminho = await ref
        .read(instaladorProvider)
        .descarregar(
          info,
          aoProgredir: (p) {
            if (state.fase == FaseDoUpdate.aDescarregar) {
              state = state.com(progresso: p);
            }
          },
        );
    if (caminho == null) {
      state = const EstadoDoUpdate(
        fase: FaseDoUpdate.falhou,
        erro: 'Não foi possível descarregar a actualização.',
      );
      return;
    }
    state = EstadoDoUpdate(fase: FaseDoUpdate.pronta, caminho: caminho);
  }

  /// Entrega ao Android. A app pode ser morta a meio disto — é o que acontece
  /// quando a instalação corre bem, e não é erro.
  Future<void> instalar() async {
    final caminho = state.caminho;
    if (caminho == null) return;
    final instalador = ref.read(instaladorProvider);

    // Nenhum ecrã do Android nesta sequência está preparado para landscape:
    // nem o pedido de autorização de fontes desconhecidas, nem o scan do
    // Play Protect, nem o instalador em si — os botões de confirmação ficam
    // fora do ecrã e o gestor não tem como lhes tocar. O shell dele pode
    // estar em landscape (Decisão 13), por isso força-se retrato já aqui,
    // antes do primeiro pedido ao sistema, e não só antes do último passo —
    // como o cadeado já faz por cima de tudo. Só se larga quando a sequência
    // termina, com sucesso ou sem ele (ver `_libertarRetrato` e o observador
    // de regresso à app, em `build`).
    await OrientacaoDoContexto.sobrepor(Orientacao.portrait);
    _aSegurarRetrato = true;

    if (!await instalador.podeInstalar()) {
      // O Android exige autorização explícita para esta app instalar pacotes.
      // Abre-se as definições; ele volta (o observador trata do retrato) e
      // carrega outra vez.
      await instalador.pedirPermissao();
      return;
    }

    state = state.com(fase: FaseDoUpdate.aInstalar);
    final desfecho = await instalador.instalar(caminho);
    if (desfecho == null) {
      await _libertarRetrato();
      state = state.com(
        fase: FaseDoUpdate.falhou,
        erro: 'A instalação não arrancou.',
      );
      return;
    }
    if (desfecho == 'pediu_confirmacao') {
      state = state.com(fase: FaseDoUpdate.aguardaConfirmacao);
    }
  }

  Future<void> _libertarRetrato() async {
    if (!_aSegurarRetrato) return;
    _aSegurarRetrato = false;
    await OrientacaoDoContexto.largarSobreposicao();
  }

  /// Wi-Fi é a única ligação que se assume gratuita. Sem forma de saber
  /// (Windows, testes), assume-se que sim — nesses casos não há plafond a
  /// gastar.
  Future<bool> _emWifi() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.any,
      );
      if (interfaces.isEmpty) return false;
      // Em Android as interfaces de dados móveis chamam-se rmnet*/ccmni*; as de
      // Wi-Fi, wlan*. Não é infalível, mas erra para o lado seguro: se não
      // reconhecer Wi-Fi, não descarrega sozinho.
      return interfaces.any((i) => i.name.startsWith('wlan'));
    } catch (erro) {
      debugPrint('[Instalador] não consegui ver a rede: $erro');
      return false;
    }
  }
}

/// Observador mínimo do ciclo de vida, só para saber quando se volta do
/// instalador do Android sem ter instalado nada.
class _ObservadorDeRegressoDoInstalador extends WidgetsBindingObserver {
  _ObservadorDeRegressoDoInstalador(this.aoRegressar);
  final VoidCallback aoRegressar;

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) aoRegressar();
  }
}
