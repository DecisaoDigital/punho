// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

/// `shared_preferences` para Windows, mas sem reescrever o ficheiro inteiro a
/// cada gravação.
///
/// O plugin oficial serializa o mapa todo e escreve-o em cada `setX`, e espera
/// por isso. No Android a mesma chamada é um `apply()` barato. Aqui, com o
/// registo de operações (~3,5 MB) e a fila de sincronização (~1 MB) dentro do
/// mesmo ficheiro, a sincronização inicial de uma empresa a sério fazia milhares
/// de gravações de 5 MB seguidas e a janela passava a «Não responde».
///
/// Mantém o formato e o caminho do plugin (`shared_preferences.json` na pasta de
/// suporte da app), por isso quem já tinha dados continua a vê-los. O mapa vive
/// em memória; a escrita é diferida e junta as gravações próximas numa só,
/// atómica (ficheiro temporário + rename), para um corte a meio não deixar o
/// JSON truncado.
class PrefsWindowsDiferido extends SharedPreferencesStorePlatform {
  PrefsWindowsDiferido({
    this.espera = const Duration(milliseconds: 600),
    this.esperaMaxima = const Duration(seconds: 5),
    Future<File> Function()? ficheiro,
  }) : _ficheiro = ficheiro ?? _ficheiroPadrao;

  static const _prefixo = 'flutter.';

  final Duration espera;

  /// Mesmo com gravações sem pausa, nunca se passa tanto tempo sem ir ao disco.
  final Duration esperaMaxima;
  final Future<File> Function() _ficheiro;

  Map<String, Object>? _mapa;
  Timer? _temporizador;
  DateTime? _sujoDesde;
  Future<void> _escritaEmCurso = Future.value();

  static Future<File> _ficheiroPadrao() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}shared_preferences.json');
  }

  /// Regista-se como implementação activa. Só faz sentido no Windows.
  static void registar() {
    SharedPreferencesStorePlatform.instance = PrefsWindowsDiferido();
  }

  Future<Map<String, Object>> _carregar() async {
    final ja = _mapa;
    if (ja != null) return ja;
    final f = await _ficheiro();
    var lido = <String, Object>{};
    try {
      if (await f.exists()) {
        final texto = await f.readAsString();
        if (texto.isNotEmpty) {
          final json = jsonDecode(texto);
          if (json is Map) {
            lido = json.map((k, v) => MapEntry(k as String, _normalizar(v)));
          }
        }
      }
    } catch (_) {
      // Ficheiro ilegível: arranca-se vazio, como o plugin oficial faz.
      lido = <String, Object>{};
    }
    // Outra chamada pode ter terminado entretanto; a primeira a chegar ganha.
    return _mapa ??= lido;
  }

  static Object _normalizar(Object? v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return v as Object;
  }

  void _agendar() {
    final agora = DateTime.now();
    _sujoDesde ??= agora;
    _temporizador?.cancel();
    final jaEsperou = agora.difference(_sujoDesde!);
    final resta = esperaMaxima - jaEsperou;
    final atraso = resta <= Duration.zero
        ? Duration.zero
        : (resta < espera ? resta : espera);
    _temporizador = Timer(atraso, () => unawaited(descarregar()));
  }

  /// Escreve já o que estiver pendente. Chamável ao fechar a app.
  Future<void> descarregar() {
    _temporizador?.cancel();
    _temporizador = null;
    final mapa = _mapa;
    if (mapa == null || _sujoDesde == null) return _escritaEmCurso;
    _sujoDesde = null;
    // Encadeia: duas escritas nunca se cruzam no mesmo ficheiro.
    _escritaEmCurso = _escritaEmCurso.then((_) async {
      try {
        final f = await _ficheiro();
        final tmp = File('${f.path}.tmp');
        await tmp.writeAsString(jsonEncode(mapa), flush: true);
        await tmp.rename(f.path);
      } catch (_) {
        // Sem disco ou sem permissão: o mapa em memória continua certo e a
        // próxima gravação tenta outra vez.
        _sujoDesde ??= DateTime.now();
      }
    });
    return _escritaEmCurso;
  }

  @override
  Future<bool> clear() => clearWithParameters(
    ClearParameters(filter: PreferencesFilter(prefix: _prefixo)),
  );

  @override
  Future<bool> clearWithPrefix(String prefix) => clearWithParameters(
    ClearParameters(filter: PreferencesFilter(prefix: prefix)),
  );

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) async {
    final filtro = parameters.filter;
    final mapa = await _carregar();
    mapa.removeWhere(
      (k, _) =>
          k.startsWith(filtro.prefix) &&
          (filtro.allowList == null || filtro.allowList!.contains(k)),
    );
    _agendar();
    return true;
  }

  @override
  Future<Map<String, Object>> getAll() => getAllWithParameters(
    GetAllParameters(filter: PreferencesFilter(prefix: _prefixo)),
  );

  @override
  Future<Map<String, Object>> getAllWithPrefix(String prefix) =>
      getAllWithParameters(
        GetAllParameters(filter: PreferencesFilter(prefix: prefix)),
      );

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) async {
    final filtro = parameters.filter;
    final copia = Map<String, Object>.from(await _carregar());
    copia.removeWhere(
      (k, _) =>
          !(k.startsWith(filtro.prefix) &&
              (filtro.allowList?.contains(k) ?? true)),
    );
    return copia;
  }

  @override
  Future<bool> remove(String key) async {
    (await _carregar()).remove(key);
    _agendar();
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    (await _carregar())[key] = value;
    _agendar();
    return true;
  }
}
