import 'package:flutter/material.dart';

import '../../../core/layout/ecra_de_formulario.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_rules.dart';
import '../../../shared/widgets/brand_lockup.dart';

/// O ecrã de entrar.
///
/// Vivia dentro do `AuthGate`, num método privado, e por isso não havia forma
/// de o montar num teste sem Supabase a correr. Foi assim que três
/// funcionalidades desapareceram num commit de branding sem nada acusar — a
/// recuperação de palavra-passe, o autofill e o olhinho. Extraído para aqui,
/// fica testável e simétrico com o [RegistoScreen], que já era um ecrã próprio.
///
/// As duas acções são injectáveis por causa disso: em produção falam com o
/// Supabase, no teste falam com o que o teste quiser.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.aoCriarConta,
    this.aoEntrar,
    this.aoRecuperar,
  });

  final VoidCallback aoCriarConta;

  /// Entrar. Devolve a mensagem de erro a mostrar, ou `null` se correu bem.
  final Future<String?> Function(String email, String palavraPasse)? aoEntrar;

  /// Pedir o email de recuperação. Devolve a mensagem de erro, ou `null`.
  final Future<String?> Function(String email)? aoRecuperar;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  /// O campo do diálogo de recuperação. Vive aqui, e não dentro do diálogo,
  /// porque descartá-lo assim que `showDialog` devolve é cedo de mais: o
  /// diálogo ainda está a animar a saída e o `TextField` continua a usá-lo —
  /// «A TextEditingController was used after being disposed». Descartado uma
  /// vez, no fim da vida do ecrã.
  final _emailDeRecuperacao = TextEditingController();

  /// O olhinho da palavra-passe. Começa escondida.
  bool _obscurarPass = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailDeRecuperacao.dispose();
    super.dispose();
  }

  @override
  // `SafeArea`: este ecrã é montado directamente pelo `AuthGate`, antes de
  // qualquer `AppShell` — não há moldura nenhuma por cima a descontar a
  // barra de estado (Decisão 8 do padrão visual). Sem isto, o topo do
  // `BrandLockup` («Punho / Agarra o comando.») ficava por baixo da barra de
  // estado do Android (visto no Redmi Note 10 Pro, Android 13, retrato).
  Widget build(BuildContext context) => Scaffold(
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
                  'Iniciar sessão',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                // `AutofillGroup` à volta dos dois campos, e não um por um: é o
                // grupo que diz ao Android que aquilo é um formulário de
                // login. Sem ele o gestor de palavras-passe não decora nem
                // oferece o que já tem guardado, e a app parece não se
                // lembrar de ninguém.
                AutofillGroup(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _email,
                        autofocus: true,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      TextField(
                        controller: _password,
                        obscureText: _obscurarPass,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _busy ? null : _entrar(),
                        decoration: InputDecoration(
                          labelText: 'Palavra-passe',
                          // Ver o que se escreveu. Numa palavra-passe longa
                          // num teclado de telemóvel, escrever às cegas é a
                          // diferença entre entrar e tentar três vezes.
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurarPass
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            tooltip: _obscurarPass
                                ? 'Mostrar palavra-passe'
                                : 'Esconder palavra-passe',
                            onPressed: () =>
                                setState(() => _obscurarPass = !_obscurarPass),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _entrar,
                  child: const Text('Entrar'),
                ),
                TextButton(
                  onPressed: _busy ? null : _recuperarPalavraPasse,
                  child: const Text('Esqueci a palavra-passe'),
                ),
                TextButton(
                  onPressed: _busy ? null : widget.aoCriarConta,
                  child: const Text('Criar conta'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _entrar() async {
    final erroEmail = AuthRules.validarEmail(_email.text);
    final erroPass = AuthRules.validarPalavraPasse(_password.text);
    if (erroEmail != null || erroPass != null) {
      setState(() => _error = erroEmail ?? erroPass);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final erro = await (widget.aoEntrar ?? _entrarNoSupabase)(
      _email.text.trim(),
      _password.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = erro;
    });
  }

  Future<String?> _entrarNoSupabase(String email, String palavraPasse) async {
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: palavraPasse,
      );
      return null;
    } on AuthException catch (e) {
      return AuthRules.mensagemSegura(e.code);
    } catch (_) {
      return AuthRules.mensagemSegura(null);
    }
  }

  Future<void> _recuperarPalavraPasse() async {
    // O email não é obrigatório antes de abrir: pede-se aqui, já preenchido com
    // o que estiver no campo, para não obrigar a voltar atrás.
    _emailDeRecuperacao.text = _email.text.trim();
    // Isto era uma caixa com 160 dp para viver: em paisagem com o teclado
    // aberto sobravam 440 px físicos, e a conta só fechava porque a explicação
    // tinha sido espremida para dentro do `helperText`. Uma vez esmagou o
    // conteúdo a zero de altura e escrevia-se às cegas. Num ecrã completo a
    // conta deixa de existir.
    final email = await abrirFormulario<String>(
      context,
      (rota) => EcraDeFormulario(
        titulo: 'Recuperar palavra-passe',
        rotuloGuardar: 'Enviar',
        campos: [
          CampoDeTexto(
            controlador: _emailDeRecuperacao,
            rotulo: 'Email',
            ajuda: 'Envio-te um link para definires uma nova palavra-passe.',
            autofocus: true,
            teclado: TextInputType.emailAddress,
          ),
        ],
        aoGuardar: () =>
            Navigator.pop(rota, _emailDeRecuperacao.text.trim()),
      ),
    );
    if (email == null || email.isEmpty) return;

    final erroEmail = AuthRules.validarEmail(email);
    if (erroEmail != null) {
      setState(() => _error = erroEmail);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final erro = await (widget.aoRecuperar ?? _recuperarNoSupabase)(email);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = erro;
    });
    if (erro != null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        // Não diz se a conta existe: a mensagem é a mesma nos dois casos, senão
        // este ecrã passa a servir para descobrir quem tem conta.
        content: Text(
          'Se existir uma conta com esse email, receberás o link em breve.',
        ),
      ),
    );
  }

  Future<String?> _recuperarNoSupabase(String email) async {
    try {
      // `punho://` e não o esquema por omissão: o default é o do POS
      // (`washinvoice://`), e o link do email caía numa página em branco.
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'punho://auth/callback',
      );
      return null;
    } on AuthException catch (e) {
      return AuthRules.mensagemSegura(e.code);
    } catch (_) {
      return AuthRules.mensagemSegura(null);
    }
  }
}
