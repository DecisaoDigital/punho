import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/finance/regime_fiscal.dart';
import 'package:punho/core/finance/retencao_irs.dart';
import 'package:punho/domain/models/workforce.dart';

/// O que sai da empresa por cada pessoa, à luz do regime fiscal.
///
/// O regime é parâmetro obrigatório e não assumido: é a Decisão 1 do guião — a
/// forma jurídica é a raiz semântica dos KPIs, e assumi-la dentro da função
/// esconderia a decisão onde ninguém a vê.
void main() {
  group('Regime não modelado', () {
    test('outro não produz estimativa nenhuma', () {
      // Inventar um cálculo genérico dava aparência de certeza a um palpite.
      for (final tipo in EmploymentType.values) {
        expect(
          estimarSalarial(
            regime: RegimeFiscal.outro,
            tipo: tipo,
            brutoMensalCents: 120000,
          ),
          isNull,
          reason: 'regime outro × ${tipo.name}',
        );
      }
    });
  });

  group('Recibos verdes', () {
    test('o valor pago é o custo total, sem TSU patronal', () {
      final e = estimarSalarial(
        regime: RegimeFiscal.eniSimplificado,
        tipo: EmploymentType.recibosVerdes,
        brutoMensalCents: 80000,
      )!;

      expect(e.custoEmpresaCents, 80000);
      expect(e.tsuEntidadePatronalCents, 0);
      expect(e.tsuTrabalhadorCents, 0);
      // A retenção é decisão de quem emite o recibo, não da empresa.
      expect(e.irsRetencaoCents, isNull);
      expect(e.liquidoTrabalhadorCents, isNull);
      expect(e.descricao, contains('Recibos verdes'));
    });

    test('vale em qualquer regime modelado', () {
      for (final regime in [
        RegimeFiscal.eniSimplificado,
        RegimeFiscal.eniOrganizado,
        RegimeFiscal.ldaIrc,
      ]) {
        final e = estimarSalarial(
          regime: regime,
          tipo: EmploymentType.recibosVerdes,
          brutoMensalCents: 50000,
        );
        expect(e?.custoEmpresaCents, 50000, reason: regime.name);
      }
    });
  });

  group('Contrato de trabalho', () {
    test('1.200 € de bruto: 132 € de TSU trabalhador, 285 € de patronal', () {
      final e = estimarSalarial(
        regime: RegimeFiscal.ldaIrc,
        tipo: EmploymentType.contrato,
        brutoMensalCents: 120000,
      )!;

      expect(e.tsuTrabalhadorCents, 13200);
      expect(e.tsuEntidadePatronalCents, 28500);
      expect(e.custoEmpresaCents, 148500);
    });

    test('a TSU patronal aplica-se também a um ENI com empregados', () {
      // Erro fácil: pensar que a TSU patronal é coisa de Lda. Um ENI com dois
      // empregados paga-a como qualquer outra entidade.
      final e = estimarSalarial(
        regime: RegimeFiscal.eniSimplificado,
        tipo: EmploymentType.contrato,
        brutoMensalCents: 100000,
      )!;

      expect(e.tsuEntidadePatronalCents, 23750);
      expect(e.custoEmpresaCents, 123750);
    });

    test('sem bruto o custo da empresa é null, não zero', () {
      final e = estimarSalarial(
        regime: RegimeFiscal.ldaIrc,
        tipo: EmploymentType.contrato,
      )!;

      expect(e.brutoCents, isNull);
      expect(e.custoEmpresaCents, isNull);
      expect(e.liquidoTrabalhadorCents, isNull);
      expect(e.irsRetencaoCents, isNull);
    });

    test('o custo da empresa existe mesmo sem os dados do trabalhador', () {
      // Bruto + TSU patronal calcula-se sem saber estado civil nem dependentes.
      final e = estimarSalarial(
        regime: RegimeFiscal.ldaIrc,
        tipo: EmploymentType.contrato,
        brutoMensalCents: 200000,
      )!;

      expect(e.custoEmpresaCents, 247500);
      expect(e.liquidoTrabalhadorCents, isNotNull);
    });

    test('casado 1 titular desconta menos IRS que solteiro', () {
      int irs(MaritalStatus estado) => estimarSalarial(
        regime: RegimeFiscal.ldaIrc,
        tipo: EmploymentType.contrato,
        estado: estado,
        brutoMensalCents: 150000,
      )!.irsRetencaoCents!;

      expect(irs(MaritalStatus.married1Holder), lessThan(irs(
        MaritalStatus.unmarried,
      )));
      expect(irs(MaritalStatus.married2Holders), lessThan(irs(
        MaritalStatus.unmarried,
      )));
    });

    test('dependentes baixam o IRS e o líquido sobe', () {
      EstimativaSalarial com(int dependentes) => estimarSalarial(
        regime: RegimeFiscal.ldaIrc,
        tipo: EmploymentType.contrato,
        dependentes: dependentes,
        brutoMensalCents: 150000,
      )!;

      expect(com(2).irsRetencaoCents, lessThan(com(0).irsRetencaoCents!));
      expect(
        com(2).liquidoTrabalhadorCents,
        greaterThan(com(0).liquidoTrabalhadorCents!),
      );
      // A TSU não muda com dependentes.
      expect(com(2).tsuTrabalhadorCents, com(0).tsuTrabalhadorCents);
    });

    test('muitos dependentes não geram IRS negativo', () {
      final e = estimarSalarial(
        regime: RegimeFiscal.ldaIrc,
        tipo: EmploymentType.contrato,
        dependentes: 40,
        brutoMensalCents: 150000,
      )!;

      expect(e.irsRetencaoCents, 0);
      expect(e.liquidoTrabalhadorCents, 150000 - e.tsuTrabalhadorCents);
    });

    test('"outro" estado civil é marcado como conservador', () {
      // Usa a coluna de solteiro, a mais pesada: o líquido sai por baixo em vez
      // de por cima, e a UI tem de o poder dizer.
      final outro = estimarSalarial(
        regime: RegimeFiscal.ldaIrc,
        tipo: EmploymentType.contrato,
        estado: MaritalStatus.other,
        brutoMensalCents: 150000,
      )!;
      final solteiro = estimarSalarial(
        regime: RegimeFiscal.ldaIrc,
        tipo: EmploymentType.contrato,
        brutoMensalCents: 150000,
      )!;

      expect(outro.estimativaConservadora, isTrue);
      expect(solteiro.estimativaConservadora, isFalse);
      expect(outro.irsRetencaoCents, solteiro.irsRetencaoCents);
    });

    test('abaixo do primeiro escalão não há IRS', () {
      final e = estimarSalarial(
        regime: RegimeFiscal.ldaIrc,
        tipo: EmploymentType.contrato,
        brutoMensalCents: 82000,
      )!;

      expect(e.irsRetencaoCents, 0);
      // Mas há TSU: as contribuições não têm mínimo de isenção.
      expect(e.tsuTrabalhadorCents, 9020);
      expect(e.custoEmpresaCents, 82000 + 19475);
    });
  });

  group('regimeDaFormaJuridica', () {
    test('as duas formas que a app oferece', () {
      expect(
        regimeDaFormaJuridica('Empresário em Nome Individual'),
        RegimeFiscal.eniSimplificado,
      );
      expect(regimeDaFormaJuridica('Lda.'), RegimeFiscal.ldaIrc);
    });

    test('forma jurídica por reconhecer vai a outro, não ao default', () {
      // Texto por reconhecer é informação, não ausência dela: uma SA não é uma
      // Lda. e não se deve calcular como se fosse.
      expect(regimeDaFormaJuridica('S.A.'), RegimeFiscal.outro);
      expect(regimeDaFormaJuridica('Cooperativa'), RegimeFiscal.outro);
    });

    test('sem forma jurídica usa o default, que é ldaIrc', () {
      // Empresa a meio do onboarding: degrada para o regime onde o cálculo de
      // trabalhador dependente ainda se aplica.
      expect(regimeDaFormaJuridica(null), RegimeFiscal.ldaIrc);
      expect(regimeDaFormaJuridica('  '), RegimeFiscal.ldaIrc);
      expect(
        regimeDaFormaJuridica(null, porOmissao: RegimeFiscal.outro),
        RegimeFiscal.outro,
      );
    });

    test('tolera variações de escrita', () {
      expect(regimeDaFormaJuridica('lda'), RegimeFiscal.ldaIrc);
      expect(regimeDaFormaJuridica('Unipessoal Lda'), RegimeFiscal.ldaIrc);
      expect(regimeDaFormaJuridica('ENI'), RegimeFiscal.eniSimplificado);
    });
  });

  group('Collaborator com os campos novos', () {
    test('o default preserva a intenção dos registos antigos', () {
      const antigo = Collaborator(
        id: 'co1',
        name: 'Manuel',
        status: CollaboratorStatus.active,
      );

      expect(antigo.employmentType, EmploymentType.contrato);
      expect(antigo.maritalStatus, MaritalStatus.unmarried);
      expect(antigo.dependents, 0);
      expect(antigo.socialSecurityNumber, isNull);
    });

    test('trocar de vínculo pode limpar o NISS', () {
      // Sentinela e não `??`: mudar para recibos verdes tem de poder apagar o
      // NISS, que deixou de fazer sentido.
      const comNiss = Collaborator(
        id: 'co1',
        name: 'Manuel',
        status: CollaboratorStatus.active,
        socialSecurityNumber: '12345678901',
      );

      expect(comNiss.copyWith(name: 'Manuel S.').socialSecurityNumber,
          '12345678901');
      expect(
        comNiss
            .copyWith(
              employmentType: EmploymentType.recibosVerdes,
              socialSecurityNumber: null,
            )
            .socialSecurityNumber,
        isNull,
      );
    });
  });
}
