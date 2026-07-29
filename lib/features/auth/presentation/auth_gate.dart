import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/orientacao/orientacao_do_contexto.dart';
import '../../../core/auth/auth_rules.dart';
import '../../collaborator/presentation/collaborator_shell.dart';
import '../../shell/presentation/app_shell.dart';
import '../acesso_providers.dart';
import '../domain/estado_acesso.dart';
import 'acesso_indisponivel_screen.dart';
import 'pedido_em_analise_screen.dart';
import 'registo_screen.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registar = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Entrar e registar são formulários: portrait, como todo o resto da app
    // fora do painel do gestor (Decisão 13).
    OrientacaoDoContexto.portraitJa();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    initialData: AuthState(
      Supabase.instance.client.auth.currentSession == null
          ? AuthChangeEvent.initialSession
          : AuthChangeEvent.signedIn,
      Supabase.instance.client.auth.currentSession,
    ),
    builder: (context, snapshot) {
      final user = snapshot.data?.session?.user;
      if (user == null) {
        return _registar
            ? RegistoScreen(
                aoVoltarParaLogin: () => setState(() {
                  _registar = false;
                  _error = null;
                }),
              )
            : _form(context);
      }
      // Ter sessão não chega: quem decide é o AcessoGate.
      return const AcessoGate();
    },
  );

  Widget _form(BuildContext context) => Scaffold(
    body: Center(
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
              Text(
                'Iniciar sessão',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Palavra-passe'),
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
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _registar = true;
                        _error = null;
                      }),
                child: const Text('Criar conta'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _recuperarPalavraPasse() async {
    // Nao bloqueamos o email se estiver vazio — pedimo-lo primeiro para o
    // utilizador nao ter de tocar em nada nem sair do sitio.
    final controller = TextEditingController(text: _email.text.trim());
    final email = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recuperar palavra-passe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Envio-te um email com o link para definir uma nova palavra-passe.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    controller.dispose();
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
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se existir uma conta com esse email, receberas o link em breve.',
          ),
        ),
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = AuthRules.mensagemSegura(e.code));
    } catch (_) {
      if (mounted) setState(() => _error = AuthRules.mensagemSegura(null));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _entrar() async {
    final emailError = AuthRules.validarEmail(_email.text);
    final passwordError = AuthRules.validarPalavraPasse(_password.text);
    if (emailError != null || passwordError != null) {
      setState(() => _error = emailError ?? passwordError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = AuthRules.mensagemSegura(e.code));
    } catch (_) {
      if (mounted) setState(() => _error = AuthRules.mensagemSegura(null));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Decide o destino de uma sessão já autenticada.
///
/// Só a existência de uma adesão activa em `punho_membros` abre a [AppShell];
/// até lá nada da empresa é carregado. Público para poder ser montado nos
/// testes com o serviço de acessos substituído.
class AcessoGate extends ConsumerWidget {
  const AcessoGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(estadoAcessoProvider).when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, __) => _erroPage(ref),
        data: (acesso) => switch (decidirAcesso(acesso)) {
          // O perfil aprovado em punho_membros escolhe a shell. Sem isto, um
          // colaborador recebia a shell de gestor e via custos, salários e
          // lucros globais.
          DecisaoAcesso.app => acesso.eGestor
              ? const AppShell()
              : CollaboratorShell(
                  collaboratorId: ref.read(acessoServiceProvider).utilizadorId,
                  titulo: 'Colaborador',
                ),
          DecisaoAcesso.pendente => const PedidoEmAnaliseScreen(),
          DecisaoAcesso.indisponivel => const AcessoIndisponivelScreen(),
        },
      );

  Widget _erroPage(WidgetRef ref) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Não foi possível confirmar o acesso à empresa.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.invalidate(estadoAcessoProvider),
              child: const Text('Tentar novamente'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => ref.read(acessoServiceProvider).terminarSessao(),
              child: const Text('Terminar sessão'),
            ),
          ],
        ),
      ),
    ),
  );
}
