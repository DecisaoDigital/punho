import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/auth_rules.dart';
import '../../../core/theme/punho_theme.dart';
import '../../auth/acesso_providers.dart';
import '../../auth/data/acesso_service.dart';

/// Base da landing pública do Punho (pasta `web/` deste repositório, servida
/// pela Vercel). É a única constante a mudar se o domínio mudar.
const kBaseLandingPunho = 'https://punho.decisaodigital.pt';

/// Link único do convite. Abre a landing que valida o código e cria a conta,
/// sem o convidado ter de instalar nada primeiro nem copiar códigos à mão.
String linkConvite(String codigo) => '$kBaseLandingPunho/convite/$codigo';

/// Página de descarga da app. Redirecciona para o GitHub Releases mais recente
/// (ver `web/vercel.json`), para o link partilhado nunca envelhecer.
const kUrlDescargaPunho = '$kBaseLandingPunho/download';

/// Constrói a mensagem completa a partilhar — link único primeiro, código como
/// recurso. É função de topo para os testes a poderem asserter sem montar o
/// diálogo nem passar pelo `launchUrl`.
///
/// O link vem à frente porque é o caminho curto: abre no telemóvel, cria a
/// conta e só depois é que a app é instalada. O código fica escrito porque a
/// landing pode não abrir (sem rede, DNS por propagar, link cortado por um
/// cliente de mensagens) e nesse caso a app aceita-o à mão.
String mensagemConvite(Convite convite) {
  final cargo = convite.perfil == 'gestor' ? 'gestor' : 'colaborador';
  return 'Olá! Foste convidado(a) para o Punho como $cargo.\n\n'
      'Abre este link no telemóvel para criares conta:\n'
      '${linkConvite(convite.codigo)}\n\n'
      'Se o link não funcionar, instala a app em\n'
      '$kUrlDescargaPunho\n'
      'e usa este código de convite: ${convite.codigo}\n\n'
      'Usa o email onde recebeste este convite — o código está preso a ele.\n'
      'Código válido durante 14 dias e de uma só utilização.';
}

/// Convites da empresa, para um gestor já aprovado.
///
/// Não há envio de emails nesta fase: o gestor copia o código e partilha-o por
/// fora. Quem se registar com ele fica ligado a esta empresa, mas continua a
/// precisar da aprovação manual do Control.
class ConvitesScreen extends ConsumerStatefulWidget {
  const ConvitesScreen({super.key, this.destacarCodigo});

  /// Código a destacar na lista. Vem das Tarefas: quando se abre este ecrã a
  /// partir de "convite sem resposta", tem de se ver logo qual é.
  final String? destacarCodigo;

  @override
  ConsumerState<ConvitesScreen> createState() => _ConvitesScreenState();
}

class _ConvitesScreenState extends ConsumerState<ConvitesScreen> {
  final _email = TextEditingController();
  String _perfil = 'colaborador';
  bool _ocupado = false;
  String? _erro;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _criar() async {
    final erroEmail = AuthRules.validarEmail(_email.text);
    if (erroEmail != null) {
      setState(() => _erro = erroEmail);
      return;
    }
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      final convite = await ref
          .read(acessoServiceProvider)
          .criarConvite(email: _email.text.trim(), perfil: _perfil);
      if (!mounted) return;
      _email.clear();
      ref.invalidate(convitesProvider);
      await _mostrarCodigo(convite);
    } on PostgrestException catch (e) {
      // As RPCs levantam P0001 com mensagem já pensada para o utilizador
      // (ex.: "Só um gestor aprovado pode criar convites.").
      if (mounted) {
        setState(
          () => _erro = e.code == 'P0001'
              ? e.message
              : AuthRules.mensagemSegura(e.code),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _erro = AuthRules.mensagemSegura(null));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _partilharWhatsApp(Convite convite) async {
    final texto = Uri.encodeComponent(mensagemConvite(convite));
    final url = Uri.parse('https://wa.me/?text=$texto');
    // externalApplication: se WhatsApp instalado, abre a app; senão o browser
    // abre wa.me que faz o redirect ou pede para instalar.
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      // Falha genuína a abrir URL (raro). Fallback: copia mensagem toda para
      // colar noutro sítio.
      await Clipboard.setData(ClipboardData(text: mensagemConvite(convite)));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não abriu o WhatsApp. Mensagem copiada.'),
        ),
      );
    }
  }

  Future<void> _mostrarCodigo(Convite convite) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Convite criado'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Partilhe este código com ${convite.email}:'),
          const SizedBox(height: 12),
          SelectableText(
            convite.codigo,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Válido 14 dias e de uma só utilização. O acesso continua sujeito '
            'a aprovação manual.',
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () => _partilharWhatsApp(convite),
          icon: const Icon(Icons.send, size: 18),
          label: const Text('Enviar por WhatsApp'),
        ),
        TextButton(
          onPressed: () =>
              Clipboard.setData(ClipboardData(text: convite.codigo)),
          child: const Text('Copiar código'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Fechar'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final convites = ref.watch(convitesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Convites')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Convide alguém para esta empresa. O código é de uso único e '
            'expira em 14 dias.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email do convidado'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _perfil,
            decoration: const InputDecoration(labelText: 'Cargo'),
            items: const [
              DropdownMenuItem(value: 'gestor', child: Text('Gestor')),
              DropdownMenuItem(
                value: 'colaborador',
                child: Text('Colaborador'),
              ),
            ],
            onChanged: _ocupado
                ? null
                : (v) => setState(() => _perfil = v ?? 'colaborador'),
          ),
          if (_erro != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_erro!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _ocupado ? null : _criar,
            child: Text(_ocupado ? 'A criar...' : 'Criar convite'),
          ),
          const SizedBox(height: 32),
          const Text(
            'Convites emitidos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          convites.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => const Text('Não foi possível ler os convites.'),
            data: (lista) => lista.isEmpty
                ? const Text('Ainda não emitiu convites.')
                : Column(
                    children: [
                      for (final c in lista)
                        _LinhaConvite(
                          convite: c,
                          destacado: c.codigo == widget.destacarCodigo,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _LinhaConvite extends StatelessWidget {
  const _LinhaConvite({required this.convite, this.destacado = false});
  final Convite convite;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final String estado;
    if (convite.usado) {
      estado = 'Utilizado';
    } else if (convite.expiradoEm(agora)) {
      estado = 'Expirado';
    } else {
      estado = 'Por utilizar';
    }
    final expira = convite.expiraEm.toLocal();
    return ListTile(
      contentPadding: destacado
          ? const EdgeInsets.symmetric(horizontal: 8)
          : EdgeInsets.zero,
      tileColor: destacado ? const Color(0xFFFFF1DA) : null,
      shape: destacado
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: PunhoTheme.orange),
            )
          : null,
      title: Text(convite.email),
      subtitle: Text(
        '${convite.perfil == 'gestor' ? 'Gestor' : 'Colaborador'} · $estado · '
        'expira ${expira.day.toString().padLeft(2, '0')}/'
        '${expira.month.toString().padLeft(2, '0')}/${expira.year}',
      ),
      trailing: convite.disponivelEm(agora)
          ? SelectableText(
              convite.codigo,
              style: const TextStyle(fontWeight: FontWeight.w700),
            )
          : null,
    );
  }
}
