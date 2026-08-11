import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/licenca/licenca_info.dart';
import '../../../core/licenca/licenca_provider.dart';

/// Identidade desta instalação, em texto que se pode ler ao telefone.
///
/// Serve para responder, sem adivinhar, a três perguntas que aparecem sempre
/// que alguma coisa corre mal: **de que empresa é este aparelho**, **que
/// aparelho é**, e **até quando é que a licença vale**.
///
/// O par `chave mestre + dispositivo` é o que identifica um posto de trabalho.
/// A chave mestre é a mesma em todos os aparelhos e terminais do mesmo
/// contribuinte — Punho e POS incluídos —, e o `machine_id` é só deste
/// aparelho. Ver `docs/design/chaves_empresa_e_dispositivo.md`.
class DiagnosticoLicenca extends ConsumerWidget {
  const DiagnosticoLicenca({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final licenca = ref.watch(licencaProvider);
    final machineId = ref.watch(machineIdProvider);
    final textos = Theme.of(context).textTheme;

    return licenca.when(
      // Sem barulho enquanto carrega nem quando falha: isto é diagnóstico, não
      // pode ser mais um sítio a dar erro por não haver rede.
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (info) {
        final mid = machineId.value ?? info?.machineId ?? '';
        if (info == null && mid.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 24),
            Text('Esta instalação', style: textos.labelLarge),
            const SizedBox(height: 8),
            if (info?.chaveMestre != null)
              _Linha(
                rotulo: 'Chave da empresa',
                valor: info!.chaveMestre!,
                copiavel: true,
              )
            else
              _Linha(
                rotulo: 'Chave da empresa',
                valor: '— ainda não atribuída',
                esbatido: true,
              ),
            if (mid.isNotEmpty)
              _Linha(
                rotulo: 'Aparelho',
                valor: _curto(mid),
                copiavel: true,
                valorCompleto: mid,
              ),
            if (info != null) ...[
              _Linha(rotulo: 'Empresa', valor: info.nome ?? '—'),
              _Linha(rotulo: 'NIF', valor: info.nif ?? '—'),
              _Linha(rotulo: 'Plano', valor: info.plano ?? '—'),
              _Linha(rotulo: 'Estado', valor: _estado(info)),
              if (info.validade != null)
                _Linha(rotulo: 'Válida até', valor: _data(info.validade!)),
            ],
          ],
        );
      },
    );
  }

  /// O `machine_id` é um hash de 64 caracteres — inteiro não se lê nem se dita.
  /// Mostram-se as pontas, que chegam para o reconhecer numa lista, e copia-se
  /// o valor completo com o toque.
  static String _curto(String mid) => mid.length <= 20
      ? mid
      : '${mid.substring(0, 8)}…${mid.substring(mid.length - 6)}';

  static String _estado(LicencaInfo info) => switch (info.estado) {
    EstadoLicenca.activa =>
      info.emTrial
          ? (info.diasRestantes == null
                ? 'Avaliação (dias por apurar)'
                : 'Avaliação (${info.diasRestantes} dias)')
          : 'Activa',
    EstadoLicenca.expirada => 'Expirada',
    EstadoLicenca.inactiva => 'Suspensa',
    EstadoLicenca.inexistente => 'Por registar',
  };

  static String _data(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _Linha extends StatelessWidget {
  final String rotulo;
  final String valor;
  final bool copiavel;
  final bool esbatido;

  /// Valor a copiar quando o mostrado está encurtado.
  final String? valorCompleto;

  const _Linha({
    required this.rotulo,
    required this.valor,
    this.copiavel = false,
    this.esbatido = false,
    this.valorCompleto,
  });

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final cores = Theme.of(context).colorScheme;

    final linha = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              rotulo,
              style: textos.bodySmall?.copyWith(color: cores.outline),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: textos.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                color: esbatido ? cores.outline : null,
              ),
            ),
          ),
          if (copiavel) Icon(Icons.copy, size: 14, color: cores.outline),
        ],
      ),
    );

    if (!copiavel) return linha;

    // Que a linha se copia ao toque diz-se por um ícone de 14 px. Quem não o
    // vê não tem como saber que ali há alguma coisa para fazer — e é
    // precisamente esta a informação (chave de licença, id do terminal) que
    // faz falta ditar a alguém ao telefone.
    return Semantics(
      button: true,
      hint: 'Tocar para copiar',
      child: InkWell(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: valorCompleto ?? valor));
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$rotulo copiada.')));
        },
        child: linha,
      ),
    );
  }
}
