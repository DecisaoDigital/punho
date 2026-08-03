import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/empresa_sync/empresa_sync_controller.dart';
import 'package:punho/core/empresa_sync/empresa_sync_service.dart';
import 'package:punho/core/empresa_sync/ficha_pendente.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Achado 3 da Faixa D: `punho_empresas.dados` ficou vazio porque a ficha ia
/// com o NIF por preencher, a Edge Function recusava-a com `nif_invalido`, e o
/// motor reenviava a mesma ficha de 20 em 20 minutos — para sempre, sem nada
/// chegar ao Control e sem ninguém ver o erro.
///
/// A causa não era o NIF: era não haver diferença entre "não deu agora" e
/// "não vai dar nunca".
class _ServicoFalso extends EmpresaSyncService {
  _ServicoFalso(this.resposta) : super(null);

  ResultadoDaFicha Function(Map<String, dynamic>) resposta;
  int tentativas = 0;

  @override
  Future<ResultadoDaFicha> sincronizar(Map<String, dynamic> dados) async {
    tentativas++;
    return resposta(dados);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FichaEmpresaPendente pendente;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    pendente = FichaEmpresaPendente(await SharedPreferences.getInstance());
  });

  EmpresaSyncEngine motorCom(_ServicoFalso servico) =>
      EmpresaSyncEngine(sync: servico, pendente: pendente);

  test('uma ficha recusada não é reenviada indefinidamente', () async {
    final servico = _ServicoFalso(
      (_) => const ResultadoDaFicha.recusada('nif_invalido'),
    );
    final motor = motorCom(servico);

    await motor.atualizarFicha({'nome': 'Alugueres Norte', 'nif': ''});
    // As rondas seguintes do temporizador de 20 em 20 minutos.
    await motor.tentarEnviar();
    await motor.tentarEnviar();
    await motor.tentarEnviar();

    expect(
      servico.tentativas,
      1,
      reason: 'insistir com o mesmo conteúdo dá sempre o mesmo resultado',
    );
    expect(pendente.motivoDaRecusa, 'nif_invalido');
  });

  test('corrigir o que faltava faz a app voltar a tentar sozinha', () async {
    // O ponto que torna isto seguro: o gestor não tem de saber que houve um
    // erro nem de carregar em nada. Corrige o NIF nas Definições e a ficha
    // segue.
    final servico = _ServicoFalso(
      (ficha) => (ficha['nif'] as String).length == 9
          ? const ResultadoDaFicha.entregue()
          : const ResultadoDaFicha.recusada('nif_invalido'),
    );
    final motor = motorCom(servico);

    await motor.atualizarFicha({'nome': 'Alugueres Norte', 'nif': ''});
    expect(servico.tentativas, 1);

    await motor.atualizarFicha({'nome': 'Alugueres Norte', 'nif': '501234567'});

    expect(servico.tentativas, 2);
    expect(pendente.ficha, isNull, reason: 'entregue, já não há pendência');
    expect(pendente.motivoDaRecusa, isNull);
  });

  test('sem rede continua a insistir — é para isso que a fila existe', () async {
    final servico = _ServicoFalso((_) => const ResultadoDaFicha.adiada());
    final motor = motorCom(servico);

    await motor.atualizarFicha({'nome': 'Alugueres Norte', 'nif': '501234567'});
    await motor.tentarEnviar();
    await motor.tentarEnviar();

    expect(
      servico.tentativas,
      3,
      reason: 'uma falha de rede não é uma recusa',
    );
    expect(pendente.ficha, isNotNull);
    expect(pendente.motivoDaRecusa, isNull);
  });

  test('entregue com sucesso limpa tudo', () async {
    final servico = _ServicoFalso((_) => const ResultadoDaFicha.entregue());
    final motor = motorCom(servico);

    await motor.atualizarFicha({'nome': 'Alugueres Norte', 'nif': '501234567'});

    expect(pendente.ficha, isNull);
    expect(pendente.jaFoiRecusadaAssim, isFalse);
  });
}
