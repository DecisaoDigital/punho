import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/orientacao/orientacao_do_contexto.dart';
import '../../collaborator/presentation/collaborator_shell.dart';
import '../../shell/presentation/app_shell.dart';
import '../acesso_providers.dart';
import '../domain/estado_acesso.dart';
import 'acesso_indisponivel_screen.dart';
import 'pedido_em_analise_screen.dart';
import 'login_screen.dart';
import 'registo_screen.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  /// Só decide entre entrar e registar. Os campos, a validação e as mensagens
  /// vivem no [LoginScreen] e no [RegistoScreen] — este widget é o porteiro.
  bool _registar = false;

  @override
  void initState() {
    super.initState();
    // Entrar e registar são formulários: portrait, como todo o resto da app
    // fora do painel do gestor (Decisão 13).
    OrientacaoDoContexto.portraitJa();
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
                aoVoltarParaLogin: () => setState(() => _registar = false),
              )
            : LoginScreen(aoCriarConta: () => setState(() => _registar = true));
      }
      // Ter sessão não chega: quem decide é o AcessoGate.
      return const AcessoGate();
    },
  );
}

/// Decide o destino de uma sessão já autenticada.
///
/// Só a existência de uma adesão activa em `punho_membros` abre a [AppShell];
/// até lá nada da empresa é carregado. Público para poder ser montado nos
/// testes com o serviço de acessos substituído.
class AcessoGate extends ConsumerWidget {
  const AcessoGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(estadoAcessoProvider)
      .when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, __) => _erroPage(ref),
        data: (acesso) => switch (decidirAcesso(acesso)) {
          // O perfil aprovado em punho_membros escolhe a shell. Sem isto, um
          // colaborador recebia a shell de gestor e via custos, salários e
          // lucros globais.
          DecisaoAcesso.app =>
            acesso.eGestor
                ? const AppShell()
                : CollaboratorShell(
                    collaboratorId: ref
                        .read(acessoServiceProvider)
                        .utilizadorId,
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
