import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'licenca_info.dart';
import 'licenca_provider.dart';
import 'licenca_service.dart';
import 'machine_id.dart';

/// Quanto tempo o Fist aguenta sem o servidor responder. Decisão do Cesar:
/// 28 horas, para lhe dar tempo de corrigir uma avaria.
const gracaOffline = Duration(hours: 28);

/// De quanto em quanto tempo o aparelho confirma que ainda tem a sessão.
/// É também o tempo máximo que o outro aparelho demora a ser fechado.
const intervaloBatimento = Duration(minutes: 2);

const chaveUltimaRespostaOk = 'fist_licenca_ultima_resposta_ok';
const chaveSessaoId = 'fist_licenca_sessao_id';

/// Onde a app está, face à licença da conta.
enum FaseLicencaFist {
  /// Ainda sem resposta; a app não bloqueia enquanto espera.
  aVerificar,

  /// Tudo em ordem.
  ok,

  /// Outro aparelho da mesma conta abriu a app.
  sessaoPerdida,

  /// A conta já usa os 2 aparelhos e este é o 3.º.
  dispositivosExcedidos,

  /// O utilizador não tem lugar activo na empresa.
  semLugar,

  /// Passaram mais de [gracaOffline] sem o servidor responder.
  semRedeDemais,
}

extension FaseLicencaFistX on FaseLicencaFist {
  bool get bloqueia => switch (this) {
    // `semLugar` não bloqueia: é o estado de quem ainda espera aprovação,
    // e o AcessoGate já tem os ecrãs certos para isso.
    FaseLicencaFist.aVerificar ||
    FaseLicencaFist.ok ||
    FaseLicencaFist.semLugar => false,
    _ => true,
  };
}

/// Resposta já lida de `licenca-fist`.
class RespostaLicencaFist {
  const RespostaLicencaFist({
    required this.fase,
    this.licenca,
    this.sessaoId,
    this.empresa,
    this.aparelhosUsados,
    this.aparelhosMaximo,
  });

  final FaseLicencaFist fase;
  final LicencaInfo? licenca;
  final String? sessaoId;
  final String? empresa;
  final int? aparelhosUsados;
  final int? aparelhosMaximo;

  factory RespostaLicencaFist.deJson(
    Map<String, dynamic> json, {
    required String machineId,
  }) {
    final disp = json['dispositivos'];
    final usados = disp is Map ? disp['usados'] as int? : null;
    final maximo = disp is Map ? disp['maximo'] as int? : null;
    switch (json['estado']) {
      case 'sem_lugar':
        return const RespostaLicencaFist(fase: FaseLicencaFist.semLugar);
      case 'dispositivos_excedidos':
        return RespostaLicencaFist(
          fase: FaseLicencaFist.dispositivosExcedidos,
          aparelhosUsados: usados,
          aparelhosMaximo: maximo,
        );
    }
    final sessao = json['sessao'];
    final ativa = sessao is Map ? sessao['ativa'] == true : true;
    final empresa = json['empresa'];
    final nomeEmpresa = empresa is Map ? empresa['nome'] as String? : null;
    return RespostaLicencaFist(
      fase: ativa ? FaseLicencaFist.ok : FaseLicencaFist.sessaoPerdida,
      sessaoId: sessao is Map ? sessao['id'] as String? : null,
      empresa: nomeEmpresa,
      aparelhosUsados: usados,
      aparelhosMaximo: maximo,
      licenca: LicencaInfo.fromJson({
        ...json,
        'nome': nomeEmpresa,
      }, machineId: machineId),
    );
  }
}

/// Passaram mais de [gracaOffline] desde a última resposta do servidor?
///
/// Um relógio que anda para trás (agora antes da última resposta) também
/// bloqueia: é a forma óbvia de esticar as 28 horas.
bool gracaEsgotada(DateTime? ultimaOk, DateTime agora) {
  if (ultimaOk == null) return false;
  if (agora.isBefore(ultimaOk.subtract(const Duration(minutes: 5)))) {
    return true;
  }
  return agora.difference(ultimaOk) > gracaOffline;
}

extension LicencaFistServico on FistLicencaService {
  /// Chama `licenca-fist`. `null` = sem rede ou o servidor falhou, para o
  /// chamador distinguir "não sei" de "não tens licença".
  Future<RespostaLicencaFist?> licencaFist(
    String machineId, {
    String? nomeDispositivo,
    bool reclamarSessao = false,
    String? sessaoId,
  }) async {
    try {
      final resposta = await invocar('licenca-fist', {
        'machine_id': machineId,
        'nome_dispositivo': ?nomeDispositivo,
        if (reclamarSessao) 'reclamar_sessao': true,
        'sessao_id': ?sessaoId,
      });
      final dados = resposta.data;
      if (resposta.status != 200 || dados is! Map) return null;
      return RespostaLicencaFist.deJson(
        Map<String, dynamic>.from(dados),
        machineId: machineId,
      );
    } catch (erro) {
      debugPrint('licenca-fist falhou: $erro');
      return null;
    }
  }
}

/// Modelo do aparelho, para a conta mostrar «Redmi Note 10 Pro» e não um hash.
Future<String?> nomeDoAparelho() async {
  try {
    if (Platform.isAndroid) {
      final a = await DeviceInfoPlugin().androidInfo;
      return '${a.manufacturer} ${a.model}';
    }
    if (Platform.isWindows) {
      return (await DeviceInfoPlugin().windowsInfo).computerName;
    }
  } catch (_) {}
  return null;
}

class EstadoLicencaFist {
  const EstadoLicencaFist({
    this.fase = FaseLicencaFist.aVerificar,
    this.resposta,
  });
  final FaseLicencaFist fase;
  final RespostaLicencaFist? resposta;
}

/// Guarda a licença da conta, a sessão única e a graça de 28 horas.
class LicencaFistController extends StateNotifier<EstadoLicencaFist> {
  LicencaFistController(
    this._servico, {
    DateTime Function()? relogio,
    Future<String> Function()? machineId,
    Future<String?> Function()? nomeDispositivo,
  }) : _agora = relogio ?? DateTime.now,
       _machineId = machineId ?? resolverMachineId,
       _nomeDispositivo = nomeDispositivo,
       super(const EstadoLicencaFist());

  final FistLicencaService _servico;
  final DateTime Function() _agora;
  final Future<String> Function() _machineId;
  final Future<String?> Function()? _nomeDispositivo;
  Timer? _batimento;
  bool _sessaoReclamada = false;

  /// Chamar quando o utilizador fica autenticado: este aparelho passa a ser o
  /// único com a sessão aberta.
  ///
  /// Reclama uma só vez por arranque: um `signedIn` repetido (token
  /// recuperado ao voltar do fundo) só revalida, senão dois aparelhos
  /// roubavam a sessão um ao outro em ciclo.
  Future<void> abrirSessao() {
    if (_sessaoReclamada) return _verificar(reclamar: false);
    _sessaoReclamada = true;
    return _verificar(reclamar: true);
  }

  /// «Usar neste aparelho»: o utilizador escolhe ficar com a sessão.
  Future<void> reabrirSessao() => _verificar(reclamar: true);

  /// Batimento, retoma da app e botão «Tentar novamente».
  Future<void> revalidar() => _verificar(reclamar: false);

  void iniciarBatimento() {
    _batimento?.cancel();
    _batimento = Timer.periodic(intervaloBatimento, (_) => revalidar());
  }

  void parar() {
    _batimento?.cancel();
    _batimento = null;
    _sessaoReclamada = false;
    state = const EstadoLicencaFist();
  }

  Future<void> _verificar({required bool reclamar}) async {
    final prefs = await SharedPreferences.getInstance();
    final machineId = await _machineId();
    final resposta = await _servico.licencaFist(
      machineId,
      nomeDispositivo: await _nomeDispositivo?.call(),
      reclamarSessao: reclamar,
      sessaoId: reclamar ? null : prefs.getString(chaveSessaoId),
    );
    if (!mounted) return;
    final agora = _agora();

    if (resposta == null) {
      final ultima = _lerData(prefs.getString(chaveUltimaRespostaOk));
      if (ultima == null) {
        // Nunca houve resposta: o relógio das 28 horas começa agora.
        await prefs.setString(
          chaveUltimaRespostaOk,
          agora.toUtc().toIso8601String(),
        );
        return;
      }
      if (gracaEsgotada(ultima, agora)) {
        state = EstadoLicencaFist(
          fase: FaseLicencaFist.semRedeDemais,
          resposta: state.resposta,
        );
      }
      return;
    }

    await prefs.setString(
      chaveUltimaRespostaOk,
      agora.toUtc().toIso8601String(),
    );
    if (reclamar && resposta.sessaoId != null) {
      await prefs.setString(chaveSessaoId, resposta.sessaoId!);
    }
    state = EstadoLicencaFist(fase: resposta.fase, resposta: resposta);
  }

  DateTime? _lerData(String? texto) =>
      texto == null ? null : DateTime.tryParse(texto);

  @override
  void dispose() {
    _batimento?.cancel();
    super.dispose();
  }
}

final licencaFistProvider =
    StateNotifierProvider<LicencaFistController, EstadoLicencaFist>(
      (ref) => LicencaFistController(
        ref.watch(licencaServiceProvider),
        nomeDispositivo: nomeDoAparelho,
      ),
    );

/// Utilizador autenticado → abre a sessão e começa o batimento; sem sessão →
/// pára. Observado uma vez no `build` da app.
final licencaFistLigacaoProvider = Provider<void>((ref) {
  if (!SupabaseConfig.enabled) return;
  final controlador = ref.read(licencaFistProvider.notifier);
  final auth = Supabase.instance.client.auth;
  if (auth.currentSession != null) {
    controlador.abrirSessao();
    controlador.iniciarBatimento();
  }
  final sub = auth.onAuthStateChange.listen((evento) {
    switch (evento.event) {
      case AuthChangeEvent.signedIn:
        controlador.abrirSessao();
        controlador.iniciarBatimento();
      case AuthChangeEvent.signedOut:
        controlador.parar();
      default:
    }
  });
  ref.onDispose(sub.cancel);
});
