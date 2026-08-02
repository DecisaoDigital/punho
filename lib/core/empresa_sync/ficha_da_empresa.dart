import '../operations/operations_controller.dart';

/// A ficha da empresa como ela viaja para o servidor, e agora de volta.
///
/// As chaves são as do payload que o ecrã de Definições da Empresa envia à
/// Edge Function `sincronizar-empresa-punho` — é o mesmo formato, lido ao
/// contrário. Estão aqui num sítio só para não haver duas listas a
/// dessincronizarem-se.
class FichaDaEmpresa {
  const FichaDaEmpresa({
    this.nomeGestor,
    this.nomeComercial,
    this.formaJuridica,
    this.nif,
    this.telefone,
    this.email,
    this.morada,
    this.codigoPostal,
    this.localidade,
    this.nColaboradores = 0,
    this.nVeiculos = 0,
    this.nMaquinas = 0,
    this.facturacaoAnoPassadoCentavos,
    this.facturacaoEsteAnoCentavos,
    this.manutencaoAnoPassadoCentavos,
    this.custosFixosMensaisCentavos,
  });

  /// Lê o que veio de `punho_empresas.dados`.
  ///
  /// Tolerante de propósito: uma ficha meio preenchida é melhor do que nenhuma,
  /// e quem a preencheu pode ter deixado campos por dizer. O que falta fica
  /// `null` e o utilizador acaba nas Definições da Empresa.
  factory FichaDaEmpresa.doServidor(Map<String, dynamic> dados) {
    String? texto(String chave) {
      final v = dados[chave];
      if (v is! String) return null;
      final limpo = v.trim();
      return limpo.isEmpty ? null : limpo;
    }

    int inteiro(String chave) {
      final v = dados[chave];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('${v ?? ''}') ?? 0;
    }

    int? centavos(String chave) {
      final v = dados[chave];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('${v ?? ''}');
    }

    return FichaDaEmpresa(
      nomeGestor: texto('nome_gestor'),
      nomeComercial: texto('nome_comercial'),
      formaJuridica: texto('forma_juridica'),
      nif: texto('nif'),
      telefone: texto('telefone'),
      email: texto('email'),
      morada: texto('morada'),
      codigoPostal: texto('codigo_postal'),
      localidade: texto('localidade'),
      nColaboradores: inteiro('n_colaboradores'),
      nVeiculos: inteiro('n_veiculos'),
      nMaquinas: inteiro('n_maquinas'),
      facturacaoAnoPassadoCentavos: centavos('facturacao_ano_passado_centavos'),
      facturacaoEsteAnoCentavos: centavos('facturacao_este_ano_centavos'),
      manutencaoAnoPassadoCentavos: centavos('manutencao_ano_passado_centavos'),
      custosFixosMensaisCentavos: centavos('custos_fixos_mensais_centavos'),
    );
  }

  final String? nomeGestor, nomeComercial, formaJuridica, nif;
  final String? telefone, email, morada, codigoPostal, localidade;
  final int nColaboradores, nVeiculos, nMaquinas;
  final int? facturacaoAnoPassadoCentavos, facturacaoEsteAnoCentavos;
  final int? manutencaoAnoPassadoCentavos, custosFixosMensaisCentavos;

  /// Uma ficha só serve para saltar o onboarding se disser o essencial: de quem
  /// é a empresa e como se chama. Sem isto a app abria o painel de uma empresa
  /// sem nome, o que é pior do que perguntar.
  bool get temOEssencial =>
      (nomeComercial != null && nomeComercial!.isNotEmpty) &&
      (nomeGestor != null && nomeGestor!.isNotEmpty);

  /// O inverso de [FichaDaEmpresa.doServidor]: o payload jsonb que se envia à
  /// Edge Function `sincronizar-empresa-punho`.
  ///
  /// Único sítio onde este mapa é montado. Antes de existir, o ecrã de
  /// Definições da Empresa tinha a sua própria cópia privada — e o fim do
  /// onboarding não tinha nenhuma, o que é a razão de as empresas chegarem ao
  /// Control sem NIF e sem nome. As chaves têm de continuar exactamente estas:
  /// é o que o trigger DB `punho_empresas_sync_licenca` lê para criar ou
  /// actualizar a `licenca`.
  Map<String, dynamic> paraPayload() => {
    // `nif` e `nome_comercial` vão sempre como string (nunca `null`): é o
    // trigger que decide se '' chega para preencher a licença, não a app.
    'nif': nif ?? '',
    'nome_comercial': nomeComercial ?? '',
    'forma_juridica': formaJuridica ?? '',
    'nome_gestor': nomeGestor,
    'morada': morada,
    'codigo_postal': codigoPostal,
    'localidade': localidade,
    'telefone': telefone,
    'email': email,
    'n_colaboradores': nColaboradores,
    'n_veiculos': nVeiculos,
    'n_maquinas': nMaquinas,
    'facturacao_ano_passado_centavos': facturacaoAnoPassadoCentavos,
    'facturacao_este_ano_centavos': facturacaoEsteAnoCentavos,
    'manutencao_ano_passado_centavos': manutencaoAnoPassadoCentavos,
    'custos_fixos_mensais_centavos': custosFixosMensaisCentavos,
  };

  /// Grava-a como se o gestor a tivesse acabado de escrever no onboarding.
  void aplicarEm(OperationsController operacoes) {
    operacoes.completeOnboarding(
      ownerName: nomeGestor ?? '',
      companyName: nomeComercial ?? '',
      legalForm: formaJuridica ?? '',
      // Só se declara frota se houver veículos declarados: dizer que sim com
      // zero veículos punha o painel a pedir dados de uma frota que não existe.
      hasFleet: nVeiculos > 0,
      collaborators: nColaboradores,
      declaredVehicleCount: nVeiculos,
      totalMachinesDeclared: nMaquinas,
      // As máquinas em concreto não vêm na ficha — só quantas são. Quem quiser
      // inserí-las fá-lo na secção Máquinas, sem ser empurrado para isso agora.
      insertMachinesNow: false,
      companyTaxId: nif,
      companyPhone: telefone,
      companyEmail: email,
      companyAddress: morada,
      companyPostalCode: codigoPostal,
      companyLocality: localidade,
      revenueLastYearCents: facturacaoAnoPassadoCentavos,
      revenueThisYearCents: facturacaoEsteAnoCentavos,
      maintenanceLastYearCents: manutencaoAnoPassadoCentavos,
      fixedMonthlyCostsCents: custosFixosMensaisCentavos,
    );
  }
}
