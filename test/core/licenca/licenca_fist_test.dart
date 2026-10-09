import 'package:flutter_test/flutter_test.dart';
import 'package:fist/core/licenca/licenca_fist.dart';
import 'package:fist/core/licenca/licenca_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Falso {
  _Falso(this.respostas);
  final List<Object> respostas; // Map = 200, Exception = lança
  final chamadas = <Map<String, dynamic>>[];
  Future<FunctionResponse> call(String nome, Map<String, dynamic> corpo) async {
    expect(nome, 'licenca-fist');
    chamadas.add(corpo);
    final r = respostas.removeAt(0);
    if (r is Exception) throw r;
    return FunctionResponse(status: 200, data: r);
  }
}

Map<String, dynamic> _ok({bool ativa = true, String sessao = 's1'}) => {
  'estado': 'activa',
  'plano': 'trial',
  'validade': '2026-11-18',
  'dias_restantes': 40,
  'empresa': {'id': 'e1', 'nome': 'Lavandaria X'},
  'dispositivos': {'usados': 1, 'maximo': 2},
  'sessao': {'id': sessao, 'ativa': ativa},
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  LicencaFistController criar(_Falso f, DateTime Function() relogio) =>
      LicencaFistController(
        FistLicencaService.comInvocador(f.call),
        relogio: relogio,
        machineId: () async => 'mid-12345678',
      );

  test('graça: 28 h exactas ainda passam, 28 h e 1 min bloqueiam', () {
    final t = DateTime.utc(2026, 10, 9, 12);
    expect(gracaEsgotada(null, t), isFalse);
    expect(gracaEsgotada(t, t.add(const Duration(hours: 28))), isFalse);
    expect(
      gracaEsgotada(t, t.add(const Duration(hours: 28, minutes: 1))),
      isTrue,
    );
  });

  test('relógio atrasado também bloqueia', () {
    final t = DateTime.utc(2026, 10, 9, 12);
    expect(gracaEsgotada(t, t.subtract(const Duration(hours: 3))), isTrue);
  });

  test('abrir sessão reclama, guarda o id e fica ok', () async {
    final f = _Falso([_ok()]);
    final c = criar(f, DateTime.now);
    await c.abrirSessao();
    expect(f.chamadas.single['reclamar_sessao'], true);
    expect(c.state.fase, FaseLicencaFist.ok);
    expect(c.state.resposta!.licenca!.nome, 'Lavandaria X');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(chaveSessaoId), 's1');
  });

  test(
    'revalidar envia o sessao_id e perde a sessão se o servidor disser',
    () async {
      final f = _Falso([_ok(), _ok(ativa: false, sessao: 's2')]);
      final c = criar(f, DateTime.now);
      await c.abrirSessao();
      await c.revalidar();
      expect(f.chamadas[1]['sessao_id'], 's1');
      expect(f.chamadas[1].containsKey('reclamar_sessao'), isFalse);
      expect(c.state.fase, FaseLicencaFist.sessaoPerdida);
      expect(c.state.fase.bloqueia, isTrue);
    },
  );

  test('segundo abrirSessao no mesmo arranque só revalida', () async {
    final f = _Falso([_ok(), _ok()]);
    final c = criar(f, DateTime.now);
    await c.abrirSessao();
    await c.abrirSessao();
    expect(f.chamadas[1].containsKey('reclamar_sessao'), isFalse);
  });

  test('«usar neste aparelho» volta a reclamar', () async {
    final f = _Falso([_ok(), _ok(ativa: false), _ok(sessao: 's3')]);
    final c = criar(f, DateTime.now);
    await c.abrirSessao();
    await c.revalidar();
    await c.reabrirSessao();
    expect(f.chamadas[2]['reclamar_sessao'], true);
    expect(c.state.fase, FaseLicencaFist.ok);
  });

  test('3.º aparelho e sem lugar', () async {
    final f = _Falso([
      {
        'estado': 'dispositivos_excedidos',
        'dispositivos': {'usados': 2, 'maximo': 2},
      },
      {'estado': 'sem_lugar'},
    ]);
    final c = criar(f, DateTime.now);
    await c.abrirSessao();
    expect(c.state.fase, FaseLicencaFist.dispositivosExcedidos);
    expect(c.state.fase.bloqueia, isTrue);
    await c.revalidar();
    expect(c.state.fase, FaseLicencaFist.semLugar);
    expect(c.state.fase.bloqueia, isFalse);
  });

  test('sem rede: 27 h continua, 29 h bloqueia, resposta repõe', () async {
    var agora = DateTime.utc(2026, 10, 9, 8);
    final f = _Falso([_ok(), Exception('rede'), Exception('rede'), _ok()]);
    final c = criar(f, () => agora);
    await c.abrirSessao();
    agora = agora.add(const Duration(hours: 27));
    await c.revalidar();
    expect(c.state.fase, FaseLicencaFist.ok);
    agora = agora.add(const Duration(hours: 2));
    await c.revalidar();
    expect(c.state.fase, FaseLicencaFist.semRedeDemais);
    await c.revalidar();
    expect(c.state.fase, FaseLicencaFist.ok);
  });

  test(
    'sem rede desde o início: o relógio começa no primeiro falhanço',
    () async {
      var agora = DateTime.utc(2026, 10, 9, 8);
      final f = _Falso([
        Exception('rede'),
        Exception('rede'),
        Exception('rede'),
      ]);
      final c = criar(f, () => agora);
      await c.abrirSessao();
      expect(c.state.fase, FaseLicencaFist.aVerificar);
      agora = agora.add(const Duration(hours: 29));
      await c.revalidar();
      expect(c.state.fase, FaseLicencaFist.semRedeDemais);
    },
  );
}
