import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/empresa_sync/ficha_da_empresa.dart';

/// A ficha da empresa, lida do servidor.
///
/// Durante muito tempo os dados da empresa só viajaram num sentido: a app
/// empurrava-os para o Supabase e nunca os lia de volta. Estava escrito no
/// código como decisão — «editados num sítio só, pelo gestor» —, mas tem uma
/// consequência que ninguém tinha visto: quem troca de telemóvel ou reinstala
/// tem os dados no servidor, sessão iniciada, permissões para os ler, e é
/// recebido pelo onboarding a perguntar «Como te chamas?».
void main() {
  /// O que o servidor tem, tal como o ecrã de Definições da Empresa o escreveu.
  final terraforte = <String, dynamic>{
    'nif': '514287934',
    'nome_comercial': 'Terraforte — Aluguer de Equipamentos',
    'forma_juridica': 'Sociedade por quotas',
    'nome_gestor': 'César Mendes',
    'morada': 'Rua da Pedreira, 42',
    'codigo_postal': '4700-727',
    'localidade': 'Braga',
    'telefone': '912480315',
    'email': 'geral@terraforte.pt',
    'n_colaboradores': 4,
    'n_veiculos': 2,
    'n_maquinas': 7,
    'facturacao_ano_passado_centavos': 18640000,
    'facturacao_este_ano_centavos': 11275000,
    'manutencao_ano_passado_centavos': 2390000,
    'custos_fixos_mensais_centavos': 845000,
  };

  test('lê a ficha inteira como ela foi escrita', () {
    final ficha = FichaDaEmpresa.doServidor(terraforte);

    expect(ficha.nomeComercial, 'Terraforte — Aluguer de Equipamentos');
    expect(ficha.nomeGestor, 'César Mendes');
    expect(ficha.nif, '514287934');
    expect(ficha.localidade, 'Braga');
    expect(ficha.nColaboradores, 4);
    expect(ficha.nMaquinas, 7);
    expect(ficha.facturacaoAnoPassadoCentavos, 18640000);
    expect(ficha.custosFixosMensaisCentavos, 845000);
  });

  test('uma ficha sem nome nem gestor não serve para saltar o onboarding', () {
    // Era este o estado da empresa antes de hoje: existia a linha, com `dados`
    // a `{}`. Aceitá-la abria o painel de uma empresa sem nome — pior do que
    // perguntar.
    expect(FichaDaEmpresa.doServidor({}).temOEssencial, isFalse);
    expect(
      FichaDaEmpresa.doServidor({'nome_comercial': 'Terraforte'}).temOEssencial,
      isFalse,
      reason: 'falta saber de quem é',
    );
    expect(FichaDaEmpresa.doServidor(terraforte).temOEssencial, isTrue);
  });

  test('campos vazios contam como ausentes', () {
    // O ecrã de Definições envia `null` no que está por preencher, mas uma
    // ficha antiga pode ter strings vazias. As duas coisas são a mesma.
    final ficha = FichaDaEmpresa.doServidor({
      'nome_comercial': 'Terraforte',
      'nome_gestor': 'César',
      'morada': '   ',
      'telefone': '',
    });

    expect(ficha.morada, isNull);
    expect(ficha.telefone, isNull);
    expect(ficha.temOEssencial, isTrue);
  });

  test('números que venham como texto continuam a ser lidos', () {
    // O jsonb não garante o tipo: quem escreveu a ficha pode ter posto "4" em
    // vez de 4, e perder os colaboradores por causa disso seria mau demais.
    final ficha = FichaDaEmpresa.doServidor({
      'nome_comercial': 'Terraforte',
      'nome_gestor': 'César',
      'n_colaboradores': '4',
      'custos_fixos_mensais_centavos': '845000',
    });

    expect(ficha.nColaboradores, 4);
    expect(ficha.custosFixosMensaisCentavos, 845000);
  });

  test('sem veículos declarados, não se declara frota', () {
    // `hasFleet` a true com zero veículos põe o painel a pedir dados de uma
    // frota que não existe.
    final semFrota = FichaDaEmpresa.doServidor({
      'nome_comercial': 'Terraforte',
      'nome_gestor': 'César',
      'n_veiculos': 0,
    });

    expect(semFrota.nVeiculos, 0);
    expect(FichaDaEmpresa.doServidor(terraforte).nVeiculos, 2);
  });
}
