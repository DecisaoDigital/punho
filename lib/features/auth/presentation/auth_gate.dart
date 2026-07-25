import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_rules.dart';
import '../../shell/presentation/app_shell.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _company = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _company.dispose();
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
      if (user == null) return _form(context);
      return _MembershipGate(userId: user.id, companyController: _company);
    },
  );

  Widget _form(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _register ? 'Criar conta' : 'Iniciar sessão',
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
                onPressed: _busy ? null : _submit,
                child: Text(_register ? 'Criar conta' : 'Entrar'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _register = !_register;
                  _error = null;
                }),
                child: Text(_register ? 'Já tenho conta' : 'Criar conta'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _submit() async {
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
      final auth = Supabase.instance.client.auth;
      if (_register) {
        await auth.signUp(email: _email.text.trim(), password: _password.text);
        if (mounted) {
          setState(() {
            _register = false;
            _error =
                'Conta criada. Confirma o email e inicia sessão para criar a empresa.';
          });
        }
      } else {
        await auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = AuthRules.mensagemSegura(e.code));
    } catch (_) {
      if (mounted) setState(() => _error = AuthRules.mensagemSegura(null));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _MembershipGate extends StatefulWidget {
  const _MembershipGate({
    required this.userId,
    required this.companyController,
  });
  final String userId;
  final TextEditingController companyController;

  @override
  State<_MembershipGate> createState() => _MembershipGateState();
}

class _MembershipGateState extends State<_MembershipGate> {
  late Future<Map<String, dynamic>?> _membership;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _membership = _loadMembership();
  }

  Future<Map<String, dynamic>?> _loadMembership() => Supabase.instance.client
      .from('punho_membros')
      .select('id, empresa_id, perfil, ativo')
      .eq('user_id', widget.userId)
      .eq('ativo', true)
      .maybeSingle();

  void _retry() => setState(() {
    _error = null;
    _membership = _loadMembership();
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
    future: _membership,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) return _retryPage();
      if (snapshot.data != null) return const AppShell();
      return _companySetup();
    },
  );

  Widget _retryPage() => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Não foi possível confirmar o acesso à empresa.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _retry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _companySetup() => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Vamos criar a tua empresa',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text('Esta conta ficará como gestor principal.'),
              const SizedBox(height: 16),
              TextField(
                controller: widget.companyController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nome da empresa'),
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
                onPressed: _busy ? null : _createCompany,
                child: Text(_busy ? 'A criar...' : 'Criar empresa'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _createCompany() async {
    final validation = AuthRules.validarNomeEmpresa(
      widget.companyController.text,
    );
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.rpc(
        'punho_criar_empresa_inicial',
        params: {'nome_empresa': widget.companyController.text.trim()},
      );
      if (mounted) _retry();
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _error = AuthRules.mensagemSegura(e.code));
    } catch (_) {
      if (mounted) setState(() => _error = AuthRules.mensagemSegura(null));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
