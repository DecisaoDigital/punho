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

  /// O que o ecrã montado pediu. É a escolha que manda quando não há nada por
  /// cima.
  static Orientacao get actual => _sobreposicao ?? _escolhaDoEcra;
  static Orientacao _escolhaDoEcra = Orientacao.livre;

  /// Imposta por um ecrã que se sobrepõe a outro sem o desmontar — hoje, só o
  /// cadeado.
  static Orientacao? _sobreposicao;

  static Future<void> forcarPortrait() => aplicar(Orientacao.portrait);

  static Future<void> forcarLandscape() => aplicar(Orientacao.landscape);

  /// Devolve o controlo ao sistema. Serve para ecrãs que não têm opinião e para
  /// os `dispose` que não querem deixar a app presa à sua escolha.
  static Future<void> libertar() => aplicar(Orientacao.livre);

  /// Um ecrã declara o que precisa.
  ///
  /// Enquanto houver sobreposição activa, a escolha fica **registada mas não
  /// aplicada**: o cadeado está à frente e não pode rodar por baixo dele. Assim
  /// que a sobreposição sair, é esta escolha que passa a valer.
  static Future<void> aplicar(Orientacao orientacao) {
    _escolhaDoEcra = orientacao;
    if (_sobreposicao != null) return Future<void>.value();
    return _pedirAoSistema(orientacao);
  }

  /// O cadeado impõe retrato por cima do que estiver montado.
  ///
  /// Não guarda fotografia do que estava: quem estava por baixo pode ainda nem
  /// ter decidido. No arranque com cadeado ligado, o que está montado quando o
  /// ecrã de bloqueio aparece é o `AuthGate` (retrato); o `AppShell`, que pede
  /// landscape, só monta depois de o acesso resolver — muitas vezes com o
  /// cadeado já à frente. Restaurar a fotografia devolvia esse retrato antigo e
  /// a app ficava de pé depois de desbloquear.
  static Future<void> sobrepor(Orientacao orientacao) {
    _sobreposicao = orientacao;
    return _pedirAoSistema(orientacao);
  }

  /// Sai a sobreposição e vale outra vez o que o ecrã de baixo pediu — incluindo
  /// o que ele tenha pedido enquanto esteve tapado.
  static Future<void> largarSobreposicao() {
    if (_sobreposicao == null) return Future<void>.value();
    _sobreposicao = null;
    return _pedirAoSistema(_escolhaDoEcra);
  }

  static Future<void> _pedirAoSistema(Orientacao orientacao) =>
      SystemChrome.setPreferredOrientations(switch (orientacao) {
        Orientacao.portrait => const [DeviceOrientation.portraitUp],
        // Um só lado, e não os dois.
        //
        // Deitar para o outro lado não traz nada e traz problema: o furo da
        // câmara muda de aresta. Numa rotação cai sobre a barra lateral, que é
        // navy e o absorve sem custo; na outra cai sobre o conteúdo e come
        // largura aos cartões. Fixar o lado torna a moldura previsível — e é
        // por isso que a barra lateral só tem de saber crescer para um lado.
        Orientacao.landscape => const [DeviceOrientation.landscapeLeft],
        Orientacao.livre => DeviceOrientation.values,
      });

  /// Versão que não faz esperar quem chama — para usar em `initState`, onde não
  /// se pode `await`.
  static void portraitJa() => unawaited(forcarPortrait());

  static void landscapeJa() => unawaited(forcarLandscape());

  static void sobreporJa(Orientacao orientacao) =>
      unawaited(sobrepor(orientacao));

  static void largarSobreposicaoJa() => unawaited(largarSobreposicao());
}

enum Orientacao { portrait, landscape, livre }
