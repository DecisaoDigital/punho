/// Regime fiscal da empresa — a raiz semântica dos KPIs financeiros.
///
/// Vem da Decisão 1 do guião do percurso: a forma jurídica não é um campo de
/// identidade, é o que decide o esqueleto fiscal de tudo o que se calcula
/// depois. Um ENI e uma Lda. não lêem "custo com pessoal", "resultado
/// provisório" ou "IVA a pagar" da mesma maneira, e em ENI o próprio
/// empresário nem conta como colaborador.
///
/// Este enum é o **mínimo viável** para as funções que já precisam de decidir.
/// O motor completo (serviço que responde "sou ENI simplificado" e a que cada
/// KPI pergunta se se aplica) é sprint dedicada. O que importa é que a API já
/// nasça a receber o regime em vez de o assumir: quando o motor chegar, só o
/// mapeamento fica mais rico — nenhuma assinatura muda.
enum RegimeFiscal {
  /// ENI em regime simplificado. O custo é presumido (75% do rendimento na
  /// prestação de serviços), portanto metade dos KPIs de margem real não se
  /// aplicam.
  eniSimplificado,

  /// ENI com contabilidade organizada. Despesas reais contam.
  eniOrganizado,

  /// Sociedade por quotas, sujeita a IRC. O sócio-gerente pode ser trabalhador
  /// dependente ou independente — depende, e a app não o sabe ainda.
  ldaIrc,

  /// Ainda não modelado. Não é um erro nem um sítio para despejar o que não se
  /// reconhece: é a resposta honesta para formas jurídicas que a app não sabe
  /// tratar (SA, cooperativa, ENI equiparado). As funções que dependem do
  /// regime devolvem "não disponível" em vez de inventar.
  outro,
}

String rotuloDeRegime(RegimeFiscal regime) => switch (regime) {
  RegimeFiscal.eniSimplificado => 'ENI — regime simplificado',
  RegimeFiscal.eniOrganizado => 'ENI — contabilidade organizada',
  RegimeFiscal.ldaIrc => 'Lda. — IRC',
  RegimeFiscal.outro => 'Regime não modelado',
};

/// Traduz a `legalForm` da empresa para regime.
///
/// A app só oferece duas formas jurídicas ("Empresário em Nome Individual" e
/// "Lda."), portanto o mapeamento é curto. Duas notas sobre o que ele **não**
/// sabe:
///
///  * Um ENI cai em `eniSimplificado` porque é o regime por omissão na lei até
///    aos 200 k€ de rendimento, e a app não pergunta se o empresário optou por
///    contabilidade organizada. Quando perguntar, é aqui que se decide.
///  * Uma forma jurídica que não se reconheça vai a `outro` — e não ao
///    [porOmissao] — porque texto por reconhecer é informação, não ausência
///    dela. O [porOmissao] serve para o caso em que **não há** forma jurídica
///    nenhuma (empresa a meio do onboarding), onde `ldaIrc` é a hipótese mais
///    útil: é o único regime em que o cálculo de trabalhador dependente se
///    aplica, portanto degrada para a resposta que ainda serve para algo.
RegimeFiscal regimeDaFormaJuridica(
  String? legalForm, {
  RegimeFiscal porOmissao = RegimeFiscal.ldaIrc,
}) {
  final texto = legalForm?.trim().toLowerCase() ?? '';
  if (texto.isEmpty) return porOmissao;
  if (texto.contains('nome individual') || texto == 'eni') {
    return RegimeFiscal.eniSimplificado;
  }
  if (texto.contains('lda') ||
      texto.contains('unipessoal') ||
      texto.contains('quotas')) {
    return RegimeFiscal.ldaIrc;
  }
  return RegimeFiscal.outro;
}
