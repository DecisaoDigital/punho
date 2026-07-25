import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/licenca/licenca_info.dart';
import '../../../core/licenca/licenca_provider.dart';

const _emailSuporte = 'cesarmendes78@gmail.com';

/// Aparência do aviso para um dado estado de licença.
@immutable
class AvisoLicenca {
  const AvisoLicenca({
    required this.mensagem,
    required this.fundo,
    required this.icone,
  });

  final String mensagem;
  final Color fundo;
  final IconData icone;
}

const _amarelo = Color(0xFFFFE9B8);
const _laranja = Color(0xFFF8C98A);
const _cinza = Color(0xFFE2E7EC);

/// Traduz o estado da licença no aviso a mostrar. `null` significa que não há
/// nada a assinalar — a app está em ordem, ou não foi possível validar.
///
/// Está separado do widget para poder ser testado sem construir a árvore.
AvisoLicenca? avisoParaLicenca(LicencaInfo? licenca) {
  if (licenca == null) return null;
  final dias = licenca.diasRestantes;
  switch (licenca.estado) {
    case EstadoLicenca.activa:
      if (!licenca.emTrial || dias > 10) return null;
      if (dias <= 3) {
        return AvisoLicenca(
          mensagem:
              'Trial termina em ${_dias(dias)} — contactar já.',
          fundo: _laranja,
          icone: Icons.priority_high_rounded,
        );
      }
      return AvisoLicenca(
        mensagem: 'Trial termina em ${_dias(dias)}. Contactar suporte.',
        fundo: _amarelo,
        icone: Icons.schedule_rounded,
      );
    case EstadoLicenca.expirada:
      return const AvisoLicenca(
        mensagem: 'Licença expirada. A app está em modo limitado.',
        fundo: Color(0xFFF8CFCB),
        icone: Icons.error_outline_rounded,
      );
    case EstadoLicenca.inactiva:
      return const AvisoLicenca(
        mensagem: 'Licença suspensa. Contactar suporte.',
        fundo: Color(0xFFF8CFCB),
        icone: Icons.block_rounded,
      );
    case EstadoLicenca.inexistente:
      return const AvisoLicenca(
        mensagem: 'Terminal por registar. A tentar registo…',
        fundo: _cinza,
        icone: Icons.hourglass_empty_rounded,
      );
  }
}

String _dias(int dias) => dias == 1 ? '1 dia' : '$dias dias';

/// Barra de estado da licença. Não mostra nada quando está tudo em ordem.
class LicencaBanner extends ConsumerStatefulWidget {
  const LicencaBanner({super.key});

  @override
  ConsumerState<LicencaBanner> createState() => _LicencaBannerState();
}

class _LicencaBannerState extends ConsumerState<LicencaBanner> {
  /// Evita repetir o registo em cada rebuild quando o estado é `inexistente`.
  bool _registoTentado = false;

  Future<void> _tentarRegistar(LicencaInfo licenca) async {
    if (_registoTentado) return;
    _registoTentado = true;
    await ref
        .read(licencaServiceProvider)
        .registarTerminal(licenca.machineId);
    if (mounted) ref.invalidate(licencaProvider);
  }

  @override
  Widget build(BuildContext context) {
    final licenca = ref.watch(licencaProvider).valueOrNull;
    final aviso = avisoParaLicenca(licenca);
    if (aviso == null) return const SizedBox.shrink();

    if (licenca!.estado == EstadoLicenca.inexistente) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _tentarRegistar(licenca),
      );
    }

    return Card(
      color: aviso.fundo,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(aviso.icone),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                aviso.mensagem,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () => launchUrl(
                Uri.parse(
                  'mailto:$_emailSuporte'
                  '?subject=${Uri.encodeComponent('Licença Punho')}',
                ),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('Contactar'),
            ),
          ],
        ),
      ),
    );
  }
}
