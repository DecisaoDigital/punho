import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/cadeado/cadeado_gate.dart';
import 'core/diagnostico/relator_de_erros.dart';
import 'shared/widgets/splash_punho.dart';

import 'core/empresa_sync/empresa_sync_service.dart';
import 'core/licenca/licenca_provider.dart';
import 'core/telemetria/pings_provider.dart';
import 'core/licenca/licenca_service.dart';
import 'core/licenca/machine_id.dart';
import 'core/operations/operations_controller.dart';
import 'core/theme/punho_theme.dart';
import 'core/config/supabase_config.dart';
import 'data/repositories/operation_repository.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/shell/presentation/app_shell.dart';
import 'features/sync/sync_providers.dart';
import 'features/updates/presentation/update_banner_wrapper.dart';

Future<void> main() async {
  // Antes de tudo, e **fora** da zona guardada de propósito.
  //
  // Um APK de release compilado sem os `--dart-define` do Supabase tem de
  // parar aqui, alto. Lá dentro não parava: o apanhador da zona engolia a
  // excepção, o `runApp` nunca chegava a correr, e o utilizador ficava com um
  // ecrã preto sem uma linha que explicasse porquê — que é pior do que o
  // silêncio que isto veio corrigir.
  SupabaseConfig.assertConfiguredOrCrash();

  // Tudo dentro da zona guardada: uma excepção assíncrona fora dela não é
  // apanhada por ninguém, e era assim que a app perdia exactamente os erros
  // que mais interessa ver — os que acontecem no arranque, em casa do cliente.
  await runZonedGuarded(_arrancar, (erro, pilha) {
    unawaited(
      relatorDeErros?.registar(tipo: 'zona', erro: erro, pilha: pilha) ??
          Future.value(),
    );
  });
}

/// O relator vive aqui em cima porque os handlers globais do Flutter não
/// recebem contexto — são funções soltas, e têm de lhe chegar de alguma forma.
RelatorDeErros? relatorDeErros;

Future<void> _arrancar() async {
  WidgetsFlutterBinding.ensureInitialized();
  relatorDeErros = await _prepararRelator();
  _instalarCapturaDeErros();
  // A área das notificações pertence visualmente à moldura da app. Sem esta
  // definição, alguns Android desenham ícones claros sobre o fundo claro do
  // conteúdo, sobretudo quando o telemóvel está em landscape.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: PunhoTheme.navyDeep,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  if (SupabaseConfig.enabled) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
    // Auto-onboarding: não bloqueia o arranque e falha em silêncio. As Edge
    // Functions aceitam a chave pública, por isso corre antes do login.
    unawaited(_registarTerminal());
    // Os erros da sessão passada sobem agora. É aqui e não no momento do erro
    // porque um erro que mata a app não tem tempo de fazer um pedido HTTP —
    // fica gravado no disco e apanha-se boleia no arranque seguinte.
    final relator = relatorDeErros;
    if (relator != null) {
      unawaited(relator.enviarPendentes(Supabase.instance.client));
    }
  }
  // Sem bloqueio de orientação no arranque: a app não sabe ainda quem a vai
  // usar. Cada ecrã decide (Decisão 13) — landscape só no shell do gestor
  // autenticado, portrait em todo o resto. Bloquear aqui era o que punha o
  // passo 4 do onboarding deitado num tablet.
  final operationsRepository = await PersistentOperationRepository.create();
  runApp(
    ProviderScope(
      overrides: [
        operationRepositoryProvider.overrideWithValue(operationsRepository),
      ],
      child: const PunhoApp(),
    ),
  );
}

/// Contexto do aparelho, colhido uma vez. Cada campo em `try` seu: um modelo
/// de telemóvel que não responda não pode impedir a app de ter relator.
Future<RelatorDeErros> _prepararRelator() async {
  final prefs = await SharedPreferences.getInstance();
  var versao = 'desconhecida';
  var machineId = 'por-resolver';
  final contexto = <String, Object?>{};
  try {
    final info = await PackageInfo.fromPlatform();
    versao = '${info.version}+${info.buildNumber}';
  } catch (_) {}
  try {
    machineId = await resolverMachineId();
  } catch (_) {}
  try {
    if (Platform.isAndroid) {
      final android = await DeviceInfoPlugin().androidInfo;
      contexto['modelo'] = android.model;
      contexto['fabricante'] = android.manufacturer;
      contexto['android'] = android.version.release;
    }
  } catch (_) {}
  return RelatorDeErros(
    prefs,
    machineId: machineId,
    versao: versao,
    contextoBase: contexto,
  );
}

void _instalarCapturaDeErros() {
  final anterior = FlutterError.onError;
  FlutterError.onError = (detalhes) {
    // Continua a apresentar como antes — em debug, o ecrã vermelho é
    // informação, não estorvo. O que muda é que agora também fica registado.
    anterior?.call(detalhes);
    unawaited(
      relatorDeErros?.registar(
            tipo: 'flutter',
            erro: detalhes.exception,
            pilha: detalhes.stack,
            contexto: {'biblioteca': detalhes.library},
          ) ??
          Future.value(),
    );
  };
  PlatformDispatcher.instance.onError = (erro, pilha) {
    unawaited(
      relatorDeErros?.registar(tipo: 'plataforma', erro: erro, pilha: pilha) ??
          Future.value(),
    );
    return true;
  };
}

Future<void> _registarTerminal() async {
  try {
    final machineId = await resolverMachineId();
    final client = Supabase.instance.client;
    // Além de registar o terminal, aproveita para corrigir `licencas.nif`
    // caso a empresa já tenha sincronizado um NIF real no servidor — é o
    // único ponto em que a instalação se liga ao NIF depois de nascer com o
    // placeholder '000000000' (ver EmpresaSyncService.buscarFicha).
    final ficha = await EmpresaSyncService(client).buscarFicha();
    await PunhoLicencaService(
      client,
    ).registarTerminal(machineId, nif: ficha?.nif);
  } catch (erro) {
    debugPrint('auto-onboarding falhou: $erro');
  }
}

class PunhoApp extends ConsumerStatefulWidget {
  const PunhoApp({super.key});
  @override
  ConsumerState<PunhoApp> createState() => _PunhoAppState();
}

class _PunhoAppState extends ConsumerState<PunhoApp> {
  bool _splashTerminou = false;

  @override
  Widget build(BuildContext context) {
    // Mantém o timer de revalidação vivo durante a vida da app.
    ref.watch(licencaRefreshProvider);
    // Idem para a sincronização entre dispositivos: observada aqui e não numa
    // shell, porque tem de correr tanto para o gestor como para o colaborador
    // — é entre os dois que os dados precisam de viajar.
    ref.watch(syncProvider);
    // E os pings: sem eles o Control sabe que o terminal existe, mas não sabe
    // quando foi usado nem que versão lá está agora.
    ref.watch(pingsProvider);
    final Widget destino = CadeadoGate(
      child: PunhoUpdateBannerWrapper(
        child: SupabaseConfig.enabled ? const AuthGate() : const AppShell(),
      ),
    );
    // Sem os `--dart-define` a app não fica avariada: fica **local**, com o
    // mesmo aspecto e sem servidor nenhum por trás. Já custou duas versões a
    // descobrir uma vez, e a 4 de Agosto de 2026 voltou a enganar-me a meio de
    // um teste no telemóvel — dei por criar um cliente que nunca chegou ao
    // Supabase. Uma fita no canto não deixa isso repetir-se.
    final comAviso = SupabaseConfig.enabled
        ? destino
        : Banner(
            message: 'SEM SERVIDOR',
            location: BannerLocation.topEnd,
            color: const Color(0xFFFF5C6E),
            child: destino,
          );
    return MaterialApp(
      title: 'Punho',
      debugShowCheckedModeBanner: false,
      theme: PunhoTheme.light,
      home: _splashTerminou
          ? comAviso
          : SplashPunho(
              aoTerminar: () => setState(() => _splashTerminou = true),
            ),
    );
  }
}
