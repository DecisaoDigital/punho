import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_rules.dart';
import '../../../shared/widgets/brand_lockup.dart';

/// Define a palavra-passe nova, depois de o link do email trazer a pessoa cá.
///
/// **Porque tem de existir.** Abrir o link de recuperação **autentica** — o
/// `supabase_flutter` apanha o `punho://auth/callback`, chama
/// `getSessionFromUrl`, e a partir daí há sessão. Sem este ecrã, quem clicasse
/// no email entrava na app sem nunca lhe ser pedida palavra-passe nenhuma: a
/// antiga continuava a valer, a pessoa julgava tê-la mudado, e no dia seguinte
/// não entrava. Um link de email a dar entrada silenciosa é pior do que o
/// problema que se foi corrigir.
///
/// Sai daqui de uma de duas maneiras: com palavra-passe nova, ou pela porta —
/// [aoDesistir] termina a sessão, que é o único jeito honesto de recusar. Ficar
/// com a sessão aberta sem ter passado por aqui era deixar a porta encostada.
class NovaPalavraPasseScreen extends StatefulWidget {
  const NovaPalavraPasseScreen({
    super.key,
    this.aoGuardar,
    required this.aoDesistir,
  });

  /// Grava a palavra-passe nova. Devolve a mensagem de erro, ou `null` se
  /// correu bem. Injectável para os testes não precisarem de Supabase.
  final Future<String?> Function(String palavraPasse)? aoGuardar;

  /// Desistir. Tem de terminar a sessão aberta pelo link.
  final VoidCallback aoDesistir;

  @override
  State<NovaPalavraPasseScreen> createState() => _NovaPalavraPasseScreenState();
}

class _NovaPalavraPasseScreenState extends State<NovaPalavraPasseScreen> {
  final _nova = TextEditingController();
  final _repetida = TextEditingController();
  bool _obscurar = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nova.dispose();
    _repetida.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    // Como no [LoginScreen]: montado antes de qualquer moldura, portanto a
    // barra de estado desconta-se aqui (Decisão 8 do padrão visual).
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandLockup(),
                const SizedBox(height: 24),
                Text(
                  'Nova palavra-passe',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Escolhe a que vais usar a partir de agora.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                AutofillGroup(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _nova,
                        autofocus: true,
                        obscureText: _obscurar,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'Palavra-passe',
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscurar = !_obscurar),
                            icon: Icon(
                              _obscurar
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            tooltip: _obscurar
                                ? 'Mostrar palavra-passe'
                                : 'Esconder palavra-passe',
                          ),
                        ),
                      ),
                      TextField(
                        controller: _repetida,
                        obscureText: _obscurar,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        onSubmitted: (_) => _busy ? null : _guardar(),
                        decoration: const InputDecoration(
                          labelText: 'Repetir palavra-passe',
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _guardar,
                  child: Text(_busy ? 'A guardar…' : 'Guardar'),
                ),
                TextButton(
                  onPressed: _busy ? null : widget.aoDesistir,
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _guardar() async {
    final nova = _nova.text;
    // As duas verificações antes de falar com o servidor: a segunda é a que
    // apanha o erro de dedos, e um erro de dedos aqui tranca a conta a seguir.
    final invalida =
        AuthRules.validarPalavraPasse(nova) ??
        (nova == _repetida.text ? null : 'As duas não são iguais.');
    if (invalida != null) {
      setState(() => _error = invalida);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final erro = await (widget.aoGuardar ?? _guardarNoSupabase)(nova);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = erro;
    });
    if (erro != null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Palavra-passe alterada.')),
    );
  }

  Future<String?> _guardarNoSupabase(String palavraPasse) async {
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: palavraPasse),
      );
      return null;
    } on AuthException catch (e) {
      return AuthRules.mensagemSegura(e.code);
    } catch (_) {
      return AuthRules.mensagemSegura(null);
    }
  }
}
