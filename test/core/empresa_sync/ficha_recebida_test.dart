import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/empresa_sync/empresa_sync_service.dart';
import 'package:punho/core/empresa_sync/ficha_da_empresa.dart';
import 'package:punho/core/empresa_sync/ficha_recebida_provider.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/data/repositories/operation_repository.dart';

/// A ficha do servidor tem mesmo de chegar ao estado da app.
///
/// O teste que faltava quando isto foi publicado na v0.1.1: os testes da
/// [FichaDaEmpresa] provavam que os dados eram bem lidos, mas nenhum provava
/// que **eram aplicados**. Foi publicado a dizer «entra directamente» e o Cesar
/// abriu a app e teve de escrever a empresa à mão na mesma.
void main() {
  ProviderContainer containerCom(EmpresaSyncService? servico) {
    final container = ProviderContainer(
      overrides: [
        operationRepositoryProvider.overrideWithValue(_RepoEmMemoria()),
        empresaSyncProvider.overrideWithValue(servico),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Um serviço que devolve sempre a mesma ficha, sem rede.
  EmpresaSyncService servicoCom(Map<String, dynamic>? dados) =>
      _ServicoFalso(dados);

  test('a empresa do servidor entra no estado da app', () async {
    final container = containerCom(
      servicoCom({
        'nome_comercial': 'Terraforte — Aluguer de Equipamentos',
        'nome_gestor': 'César Mendes',
        'nif': '514287934',
        'localidade': 'Braga',
        'n_colaboradores': 4,
        'n_veiculos': 2,
        'n_maquinas': 7,
      }),
    );

    expect(container.read(operationsProvider).onboarded, isFalse);

    final trouxe = await container.read(fichaRecebidaProvider.future);

    expect(trouxe, isTrue, reason: 'devia ter trazido a ficha');
    final estado = container.read(operationsProvider);
    expect(
      estado.onboarded,
      isTrue,
      reason: 'trouxe a ficha mas continua a pedir o onboarding',
    );
    expect(estado.companyName, 'Terraforte — Aluguer de Equipamentos');
    expect(estado.ownerName, 'César Mendes');
    expect(estado.companyTaxId, '514287934');
    expect(estado.declaredCollaboratorCount, 4);
    expect(estado.totalMachinesDeclared, 7);
  });

  test('sem ficha no servidor, o onboarding continua a ser preciso', () async {
    final container = containerCom(servicoCom(null));

    expect(await container.read(fichaRecebidaProvider.future), isFalse);
    expect(container.read(operationsProvider).onboarded, isFalse);
  });

  test('uma ficha sem o essencial não serve', () async {
    // Era este o estado da empresa antes de hoje: a linha existia com `{}`.
    final container = containerCom(servicoCom({'nif': '514287934'}));

    expect(await container.read(fichaRecebidaProvider.future), isFalse);
    expect(container.read(operationsProvider).onboarded, isFalse);
  });

  test('sem Supabase não se vai buscar nada', () async {
    final container = containerCom(null);

    expect(await container.read(fichaRecebidaProvider.future), isFalse);
  });
}

class _ServicoFalso implements EmpresaSyncService {
  _ServicoFalso(this.dados);
  final Map<String, dynamic>? dados;

  @override
  Future<FichaDaEmpresa?> buscarFicha() async {
    if (dados == null) return null;
    final ficha = FichaDaEmpresa.doServidor(dados!);
    return ficha.temOEssencial ? ficha : null;
  }

  @override
  Future<ResultadoDaFicha> sincronizar(Map<String, dynamic> dados) async =>
      const ResultadoDaFicha.entregue();

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// O repositório local a sério, em memória — o mesmo que a app usa no modo de
/// demonstração. Um fake com `noSuchMethod` a devolver `null` rebentava assim
/// que o controlador lia uma lista.
class _RepoEmMemoria extends LocalDemoOperationRepository {}
