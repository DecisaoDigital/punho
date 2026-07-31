import 'dart:async';

import 'package:flutter/services.dart';

/// Orientação decidida pelo ecrã que está montado, e por mais nada.
///
/// **Um só ecrã em toda a app leva landscape: o shell do gestor autenticado.**
/// Todos os outros são portrait. É a Decisão 13 do guião, e nasceu de um bug: o
/// passo 4 do onboarding aparecia em landscape num tablet.
///
/// A causa era o `main.dart` bloquear landscape no arranque, antes de se saber
/// quem ia usar a app. O antigo `PhoneOrientationLock` tentava corrigir isso por
/// dentro, mas só actuava em telemóveis (`shortestSide < 600`) — num tablet o
/// bloqueio global ganhava e o onboarding ficava deitado, a preencher campos.
///
/// Daí a regra ser por contexto e não global: cada rota diz o que precisa no
/// `initState`, e quem não diz nada fica como estava. Sem excepções por tipo de
/// dispositivo — um tablet a fazer onboarding está nas mãos de alguém a
/// escrever, tal como um telemóvel.
class OrientacaoDoContexto {
  const OrientacaoDoContexto._();

  /// A última escolha feita por um ecrã.
  ///
  /// Serve para um ecrã que se sobrepõe a outro — o cadeado — poder impor a sua
  /// orientação e devolver a anterior ao sair. Sem isto, desbloquear deixava a
  /// app em portrait: o shell do gestor já tinha corrido o `initState` e não
  /// volta a correr, portanto ninguém repunha o landscape.
  static Orientacao get actual => _actual;
  static Orientacao _actual = Orientacao.livre;

  static Future<void> forcarPortrait() => aplicar(Orientacao.portrait);

  static Future<void> forcarLandscape() => aplicar(Orientacao.landscape);

  /// Devolve o controlo ao sistema. Serve para ecrãs que não têm opinião e para
  /// os `dispose` que não querem deixar a app presa à sua escolha.
  static Future<void> libertar() => aplicar(Orientacao.livre);

  static Future<void> aplicar(Orientacao orientacao) {
    _actual = orientacao;
    return SystemChrome.setPreferredOrientations(switch (orientacao) {
      Orientacao.portrait => const [DeviceOrientation.portraitUp],
      Orientacao.landscape => const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      Orientacao.livre => DeviceOrientation.values,
    });
  }

  /// Versão que não faz esperar quem chama — para usar em `initState`, onde não
  /// se pode `await`.
  static void portraitJa() => unawaited(forcarPortrait());

  static void landscapeJa() => unawaited(forcarLandscape());

  static void aplicarJa(Orientacao orientacao) =>
      unawaited(aplicar(orientacao));
}

enum Orientacao { portrait, landscape, livre }
