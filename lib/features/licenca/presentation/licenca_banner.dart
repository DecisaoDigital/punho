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
      // Sem dias declarados não há contagem para mostrar. Antes o `null` vinha
      // como zero e isto anunciava "termina em 0 dias — contactar já" a quem
      // tinha o trial inteiro pela frente: um alarme falso a partir de uma
      // ausência.
      if (dias == null) return null;
      if (!licenca.emTrial || dias > 10) return null;
      if (dias <= 3) {
        return AvisoLicenca(
          mensagem: 'Trial termina em ${_dias(dias)} — contactar já.',
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
        // Não diz "modo limitado" porque não há modo limitado nenhum:
        // `LicencaInfo.funcional` não tem um único consumidor e nada na app
        // está restringido. Prometer uma limitação que não existe ensina o
        // utilizador a ignorar o aviso — e no dia em que houver limitação a
        // sério, ele já não acredita nela.
        mensagem: 'Licença expirada. Contactar suporte para renovar.',
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

/// O aviso que foi posto de lado nesta sessão, `null` se nenhum.
///
/// «deve aparecer a todos os inícios, mas deve poder ser removida» — Cesar,
/// 5/8/2026. É por isso que isto vive em memória e não em disco: fechar a barra
/// vale até a app fechar, e no arranque seguinte ela está lá outra vez.
///
/// Guarda a **mensagem** e não um `bool` porque o aviso muda: quem dispensou
/// "termina em 4 dias" não dispensou "licença expirada", nem sequer "termina em
/// 3 dias" — isso é notícia nova, e notícia nova volta a aparecer.
final avisoDispensadoProvider = StateProvider<String?>((ref) => null);

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
    await ref.read(licencaServiceProvider).registarTerminal(licenca.machineId);
    if (mounted) ref.invalidate(licencaProvider);
  }

  @override
  Widget build(BuildContext context) {
    final licenca = ref.watch(licencaProvider).valueOrNull;
    final aviso = avisoParaLicenca(licenca);
    if (aviso == null) return const SizedBox.shrink();
    if (ref.watch(avisoDispensadoProvider) == aviso.mensagem) {
      return const SizedBox.shrink();
    }

    if (licenca!.estado == EstadoLicenca.inexistente) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _tentarRegistar(licenca),
      );
    }

    return Card(
      color: aviso.fundo,
      // O `Card` traz 4 de margem a toda a volta por omissão; em cima e em
      // baixo chega bem, aos lados fica curto ao pé do canvas.
      margin: const EdgeInsets.symmetric(
        horizontal: _lateral,
        vertical: _dentro,
      ),
      child: Padding(
        // À direita o X já traz o ar dele por dentro — a margem daquele lado
        // desconta-o, senão o glifo caía a 22 do bordo e o da esquerda a 12.
        padding: const EdgeInsets.fromLTRB(_lateral, _dentro, _entre, _dentro),
        child: Row(
          children: [
            Icon(aviso.icone, size: _icone),
            const SizedBox(width: _entre),
            Expanded(
              child: Text(
                aviso.mensagem,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: _entre),
            TextButton(
              style: _compacto,
              onPressed: () => launchUrl(
                Uri.parse(
                  'mailto:$_emailSuporte'
                  '?subject=${Uri.encodeComponent('Licença Punho')}',
                ),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('Contactar'),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: _icone),
              // Por omissão o `IconButton` reserva 48 de alvo e é ele, sozinho,
              // a mandar na altura da barra. `compact` tira-lhe 8 e fica nos
              // 40 — que é o que manda na barra agora, e é onde deve parar: um
              // X que se falha ao toque não serve para dispensar nada.
              constraints: const BoxConstraints.tightFor(width: _alvo),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              tooltip: 'Dispensar até à próxima vez que abrir a app',
              onPressed: () => ref.read(avisoDispensadoProvider.notifier).state =
                  aviso.mensagem,
            ),
          ],
        ),
      ),
    );
  }
}

/// A barra estava a 88 dp de altura — 23% do ecrã do Redmi deitado, medidos, só
/// para dizer uma linha. «está muito alta» — Cesar, 5/8/2026. Tinha `titleMedium`
/// (o tamanho de um título de secção), 16 de padding aos quatro lados e um
/// `FilledButton` de tamanho inteiro.
const _lateral = 12.0;

/// Em cima e em baixo, por dentro e por fora. Fica pequeno porque o X já traz
/// 10 de ar próprio de cada lado — descontá-lo aqui é o que dá os ~14 que se
/// vêem.
const _dentro = 4.0;
const _entre = 8.0;
const _icone = 20.0;

/// Onde o dedo pode cair. Manda na altura da barra.
const _alvo = 40.0;

final _compacto = TextButton.styleFrom(
  minimumSize: const Size(0, _alvo),
  padding: const EdgeInsets.symmetric(horizontal: _entre),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);
