import 'package:flutter/material.dart';

import '../../../core/finance/regime_fiscal.dart';
import '../../../core/finance/retencao_irs.dart';
import '../../../domain/models/workforce.dart';

/// Campos da ficha fiscal de um colaborador.
///
/// Existe como enum e não como parâmetros fixos porque o mesmo formulário vai
/// servir dois donos: o gestor, que preenche o que sabe, e — na sprint do
/// self-service — o próprio colaborador no telemóvel dele, que preenche IBAN,
/// morada e data de nascimento. Acrescentar um campo é acrescentar um valor
/// aqui, não abrir o widget.
enum CampoDaFichaFiscal {
  nif,
  niss,
  estadoCivil,
  dependentes,
  iban,
  moradaPessoal,
  dataNascimento,
}

/// Os campos que cada vínculo exige.
///
/// A regra é: só se pede o que muda alguma coisa. Em recibos verdes os dados
/// fiscais do prestador (NISS, estado civil, dependentes) não afectam o custo da
/// empresa nem o que ela tem de declarar — os descontos são dele. O que a
/// empresa precisa é do NIF, para lançar a despesa contra alguém.
Set<CampoDaFichaFiscal> camposDaFicha(EmploymentType tipo) => switch (tipo) {
  EmploymentType.recibosVerdes => const {
    CampoDaFichaFiscal.nif,
    CampoDaFichaFiscal.iban,
    CampoDaFichaFiscal.moradaPessoal,
  },
  EmploymentType.contrato => const {
    CampoDaFichaFiscal.niss,
    CampoDaFichaFiscal.estadoCivil,
    CampoDaFichaFiscal.dependentes,
    CampoDaFichaFiscal.iban,
    CampoDaFichaFiscal.moradaPessoal,
  },
};

/// Controladores da ficha, num sítio só.
///
/// Quem monta o formulário é dono deles e chama [dispose] — a regra da casa,
/// depois de três bugs na v0.0.5 com controladores mortos a serem reconstruídos
/// durante a animação de fecho dos diálogos.
class ControladoresDaFicha {
  ControladoresDaFicha({Collaborator? de})
    : niss = TextEditingController(text: de?.socialSecurityNumber),
      nif = TextEditingController(text: de?.taxId),
      dependentes = TextEditingController(text: '${de?.dependents ?? 0}'),
      iban = TextEditingController(),
      morada = TextEditingController();

  final TextEditingController niss, nif, dependentes, iban, morada;

  void dispose() {
    for (final controlador in [niss, nif, dependentes, iban, morada]) {
      controlador.dispose();
    }
  }
}

/// Formulário da ficha fiscal, com os campos que o vínculo exige.
class FichaFiscalColaboradorForm extends StatelessWidget {
  const FichaFiscalColaboradorForm({
    super.key,
    required this.tipo,
    required this.controladores,
    required this.estadoCivil,
    required this.aoMudarEstadoCivil,
    this.campos,
  });

  final EmploymentType tipo;
  final ControladoresDaFicha controladores;
  final MaritalStatus estadoCivil;
  final ValueChanged<MaritalStatus> aoMudarEstadoCivil;

  /// Por omissão, os campos que o vínculo pede. A sprint do self-service passa
  /// um conjunto próprio — o colaborador vê os dele e mais nada.
  final Set<CampoDaFichaFiscal>? campos;

  @override
  Widget build(BuildContext context) {
    final mostrar = campos ?? camposDaFicha(tipo);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mostrar.contains(CampoDaFichaFiscal.nif))
          _CampoComAviso(
            controlador: controladores.nif,
            rotulo: 'NIF do prestador',
            teclado: TextInputType.number,
            // Não bloqueia: a app aceita dados parciais e sinaliza o que falta.
            // Um NIF a meio de ser escrito não é um erro, é trabalho em curso.
            aviso: (valor) => valor.isEmpty || _digitos(valor).length == 9
                ? null
                : 'NIF parece incompleto',
          ),
        if (mostrar.contains(CampoDaFichaFiscal.niss))
          _CampoComAviso(
            controlador: controladores.niss,
            rotulo: 'NISS',
            teclado: TextInputType.number,
            aviso: (valor) {
              if (valor.isEmpty) return null;
              final digitos = _digitos(valor);
              return RegExp(r'^[12]\d{10}$').hasMatch(digitos)
                  ? null
                  : 'NISS parece incompleto';
            },
          ),
        if (mostrar.contains(CampoDaFichaFiscal.estadoCivil))
          DropdownButtonFormField<MaritalStatus>(
            value: estadoCivil,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Estado civil'),
            items: MaritalStatus.values
                .map(
                  (estado) => DropdownMenuItem(
                    value: estado,
                    child: Text(rotuloDeEstadoCivil(estado)),
                  ),
                )
                .toList(),
            onChanged: (v) => aoMudarEstadoCivil(v ?? MaritalStatus.unmarried),
          ),
        if (mostrar.contains(CampoDaFichaFiscal.dependentes))
          TextField(
            controller: controladores.dependentes,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Nº de dependentes',
              helperText: 'Contam para a estimativa de IRS do trabalhador.',
            ),
          ),
        if (mostrar.contains(CampoDaFichaFiscal.iban))
          TextField(
            controller: controladores.iban,
            decoration: const InputDecoration(labelText: 'IBAN'),
          ),
        if (mostrar.contains(CampoDaFichaFiscal.moradaPessoal))
          TextField(
            controller: controladores.morada,
            decoration: const InputDecoration(labelText: 'Morada'),
          ),
      ],
    );
  }
}

String _digitos(String valor) => valor.replaceAll(RegExp(r'\D'), '');

/// Campo que avisa sem impedir.
class _CampoComAviso extends StatefulWidget {
  const _CampoComAviso({
    required this.controlador,
    required this.rotulo,
    required this.aviso,
    this.teclado,
  });

  final TextEditingController controlador;
  final String rotulo;
  final String? Function(String) aviso;
  final TextInputType? teclado;

  @override
  State<_CampoComAviso> createState() => _CampoComAvisoState();
}

class _CampoComAvisoState extends State<_CampoComAviso> {
  @override
  Widget build(BuildContext context) {
    final aviso = widget.aviso(widget.controlador.text.trim());
    return TextField(
      controller: widget.controlador,
      keyboardType: widget.teclado,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: widget.rotulo,
        // `errorText` seria mentira: não há erro, há um número por acabar. O
        // âmbar diz "confere isto" sem dizer "isto está mal".
        helperText: aviso,
        helperStyle: aviso == null
            ? null
            : const TextStyle(color: Color(0xFF8A5A00)),
        helperMaxLines: 2,
      ),
    );
  }
}

/// Bloco read-only com o que a empresa paga e o trabalhador recebe.
///
/// Nunca guarda o que mostra: recalcula sempre. Um valor destes em base de dados
/// envelhece em silêncio quando as taxas mudam de ano.
class BlocoDeEstimativa extends StatelessWidget {
  const BlocoDeEstimativa({
    super.key,
    required this.regime,
    required this.tipo,
    required this.estadoCivil,
    required this.dependentes,
    required this.brutoMensalCents,
  });

  final RegimeFiscal regime;
  final EmploymentType tipo;
  final MaritalStatus estadoCivil;
  final int dependentes;
  final int? brutoMensalCents;

  @override
  Widget build(BuildContext context) {
    final estimativa = estimarSalarial(
      regime: regime,
      tipo: tipo,
      estado: estadoCivil,
      dependentes: dependentes,
      brutoMensalCents: brutoMensalCents,
    );
    final cores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cores.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Estimativa', style: textos.labelLarge),
          const SizedBox(height: 8),
          if (estimativa == null)
            // Regime que a app não modela: não se inventa um cálculo genérico.
            Text(
              'Estimativa não disponível para este regime × contrato; edita '
              'manualmente.',
              style: textos.bodySmall,
            )
          else if (tipo == EmploymentType.recibosVerdes)
            Text(
              'Recibos verdes: o valor pago é o custo total para a empresa. O '
              'prestador é responsável pelos próprios descontos.',
              style: textos.bodySmall,
            )
          else ...[
            _Linha(
              'Líquido para o trabalhador',
              estimativa.liquidoTrabalhadorCents,
              textos: textos,
            ),
            _Linha(
              'TSU entidade patronal (23,75%)',
              estimativa.tsuEntidadePatronalCents,
              textos: textos,
              sinal: '+',
            ),
            const Divider(height: 16),
            _Linha(
              'Custo total para a empresa',
              estimativa.custoEmpresaCents,
              textos: textos,
              destacado: true,
            ),
            if (estimativa.estimativaConservadora)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Estado civil "Outro" é calculado pela tabela de solteiro, a '
                  'mais pesada: o líquido real tende a ser maior.',
                  style: textos.bodySmall,
                ),
              ),
          ],
          if (estimativa != null && tipo == EmploymentType.contrato) ...[
            const SizedBox(height: 8),
            Text(
              'Estimativa. Confirma com o teu contabilista antes de folhas '
              'oficiais.',
              style: textos.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha(
    this.titulo,
    this.cents, {
    required this.textos,
    this.destacado = false,
    this.sinal = '',
  });

  final String titulo;
  final int? cents;
  final TextTheme textos;
  final bool destacado;
  final String sinal;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            titulo,
            style: destacado
                ? textos.bodyMedium?.copyWith(fontWeight: FontWeight.w800)
                : textos.bodySmall,
          ),
        ),
        Text(
          // Sem bruto declarado não há números: "por apurar" e não 0 €, que se
          // leria como "não custa nada".
          cents == null
              ? 'por apurar'
              : '$sinal${(cents! / 100).toStringAsFixed(2)} €',
          style: destacado
              ? textos.titleMedium?.copyWith(fontWeight: FontWeight.w800)
              : textos.bodySmall,
        ),
      ],
    ),
  );
}
