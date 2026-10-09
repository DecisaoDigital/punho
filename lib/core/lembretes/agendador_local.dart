import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'agendador.dart';
import 'reconciliar.dart';

/// Idêntico ao protótipo que disparou 3/3 em segundo plano no Redmi (MIUI 14):
/// `exactAllowWhileIdle`, categoria `alarm`, importância máxima.
class AgendadorLocal implements AgendadorDeLembretes {
  AgendadorLocal();

  static const _canal = 'reunioes';
  static const _idDoTeste = 2147483000;

  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _pronto;

  Future<void> _init() => _pronto ??= () async {
    tzdata.initializeTimeZones();
    final fuso = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(fuso.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }();

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  static const _detalhes = NotificationDetails(
    android: AndroidNotificationDetails(
      _canal,
      'Reuniões',
      channelDescription: 'Avisos das reuniões que marcaste',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
    ),
  );

  Future<void> _agendar(int id, DateTime quando, String texto) =>
      _plugin.zonedSchedule(
        id: id,
        title: 'Reunião',
        body: texto,
        scheduledDate: tz.TZDateTime.from(quando, tz.local),
        notificationDetails: _detalhes,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

  @override
  Future<void> aplicar(List<LembreteAgendado> plano) async {
    await _init();
    await _plugin.cancelAll();
    for (final l in plano) {
      await _agendar(l.idNotificacao, l.quando, l.texto);
    }
  }

  @override
  Future<void> cancelarTudo() async {
    await _init();
    await _plugin.cancelAll();
  }

  @override
  Future<PermissoesDoAlarme> permissoes() async {
    await _init();
    final a = _android;
    if (a == null) return PermissoesDoAlarme.todas;
    return PermissoesDoAlarme(
      notificacoes: await a.areNotificationsEnabled() ?? false,
      exacto: await a.canScheduleExactNotifications() ?? false,
    );
  }

  @override
  Future<PermissoesDoAlarme> pedirPermissoes() async {
    await _init();
    final a = _android;
    if (a == null) return PermissoesDoAlarme.todas;
    if (await a.areNotificationsEnabled() != true) {
      await a.requestNotificationsPermission();
    }
    if (await a.canScheduleExactNotifications() != true) {
      await a.requestExactAlarmsPermission();
    }
    return permissoes();
  }

  @override
  Future<void> testar({int segundos = 60}) async {
    await _init();
    await _agendar(
      _idDoTeste,
      DateTime.now().add(Duration(seconds: segundos)),
      'Teste do alarme: se estás a ver isto, as reuniões vão avisar-te.',
    );
  }
}

/// O agendador certo para a plataforma: alarme real só em Android.
AgendadorDeLembretes agendadorDaPlataforma() =>
    Platform.isAndroid ? AgendadorLocal() : const AgendadorNulo();
