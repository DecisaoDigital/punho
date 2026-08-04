import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_rules.dart';
import '../../../core/orientacao/orientacao_do_contexto.dart';
import '../../collaborator/presentation/collaborator_shell.dart';
import '../../shell/presentation/app_shell.dart';
import '../acesso_providers.dart';
import '../domain/estado_acesso.dart';
import '../domain/modo_de_recuperacao.dart';
import 'acesso_indisponivel_screen.dart';
import 'pedido_em_analise_screen.dart';
import 'login_screen.dart';
import 'nova_palavra_passe_screen.dart';
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

  /// A pessoa chegou aqui pelo link do email de recuperação. Ver
  /// [modoDeRecuperacao], que é quem manda nisto e explica porque é um trinco.
  bool _aRecuperar = false;
  StreamSubscription<AuthState>? _eventos;

  @override
  void initState() {
    super.initState();
    // Entrar e registar são formulários: portrait, como todo o resto da app
    // fora do painel do gestor (Decisão 13).
    OrientacaoDoContexto.portraitJa();
    _eventos = Supabase.instance.client.auth.onAuthStateChange.listen(
      (estado) {
        final recuperar = modoDeRecuperacao(estado.event, actual: _aRecuperar);
        if (recuperar != _aRecuperar && mounted) {
          setState(() => _aRecuperar = recuperar);
        }
      },
      // Sem isto, um link de email caducado rebentava para fora da zona — duas
      // vezes, uma por cada quem escuta — e ninguém dizia nada a quem tinha
      // acabado de carregar nele.
      onError: _falhouOLink,
    );
  }

  /// O link do email não deu em nada. Diz-se, em vez de não acontecer nada.
  ///
  /// Quem carrega num link de recuperação e vê a app abrir na mesma como estava
  /// conclui que carregou mal, e tenta outra vez — e o link seguinte também já
  /// expirou. Uma frase resolve a tarde.
  void _falhouOLink(Object erro) {
    if (!mounted) return;
    final mensagem = erro is AuthException
        ? AuthRules.mensagemSegura(erro.code)
        : AuthRules.mensagemSegura(null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensagem)));
    });
  }

  @override
  void dispose() {
    _eventos?.cancel();
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
      // **Um erro no stream não é uma sessão fechada.** O `getSessionFromUrl`
      // a falhar — um link de email caducado, por exemplo — é publicado como
      // erro aqui, e o `StreamBuilder` troca os dados pelo erro: quem estava a
      // trabalhar dentro da app era atirado para o ecrã de entrar, como se
      // tivesse terminado sessão. Visto no Redmi a 4 de Agosto de 2026, ao
      // testar o link de recuperação com um token expirado.
      //
      // Quem sabe se há sessão é o cliente, não o último evento que passou.
      final user =
          snapshot.data?.session?.user ??
          Supabase.instance.client.auth.currentSession?.user;
      if (user == null) {
        return _registar
            ? RegistoScreen(
                aoVoltarParaLogin: () => setState(() => _registar = false),
              )
            : LoginScreen(aoCriarConta: () => setState(() => _registar = true));
      }
      // Antes do acesso à empresa: quem entrou por um link de recuperação
      // ainda não escolheu palavra-passe nenhuma.
      if (_aRecuperar) {
        return NovaPalavraPasseScreen(
          // Desistir tem de fechar a sessão que o link abriu. Deixá-la aberta
          // era dar entrada a quem só clicou num email.
          aoDesistir: () => Supabase.instance.client.auth.signOut(),
        );
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
