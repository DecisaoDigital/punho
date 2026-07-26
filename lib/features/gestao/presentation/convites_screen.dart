import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_rules.dart';
import '../../auth/acesso_providers.dart';
import '../../auth/data/acesso_service.dart';

/// Convites da empresa, para um gestor já aprovado.
///
/// Não há envio de emails nesta fase: o gestor copia o código e partilha-o por
/// fora. Quem se registar com ele fica ligado a esta empresa, mas continua a
/// precisar da aprovação manual do Control.
class ConvitesScreen extends ConsumerStatefulWidget {
  const ConvitesScreen({super.key});

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
            value: _perfil,
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
            loading: () =>
                const Center(child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                )),
            error: (_, __) => const Text('Não foi possível ler os convites.'),
            data: (lista) => lista.isEmpty
                ? const Text('Ainda não emitiu convites.')
                : Column(
                    children: [
                      for (final c in lista) _LinhaConvite(convite: c),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _LinhaConvite extends StatelessWidget {
  const _LinhaConvite({required this.convite});
  final Convite convite;

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
      contentPadding: EdgeInsets.zero,
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
