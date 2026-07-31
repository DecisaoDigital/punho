import 'package:flutter/material.dart';

import '../../../core/cadeado/definicoes_cadeado_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_rules.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/operations/operations_controller.dart';
import '../../auth/acesso_providers.dart';
import '../../company/presentation/company_settings_page.dart';
import '../../gestao/presentation/convites_screen.dart';

/// Quem está autenticado, e como sair.
///
/// Era um buraco básico: o avatar no fundo da barra lateral não fazia nada — só
/// tinha um tooltip. Não havia forma de ver quem estava ligado nem de terminar
/// sessão sem procurar o ícone certo entre os outros. Num dispositivo partilhado
/// isso deixa a conta anterior presa lá dentro.
///
/// **Popup e não página.** Identidade e sair são duas linhas e um botão; abrir um
/// ecrã inteiro para isto seria desproporcionado. A edição dos dados da empresa
/// **não** vive aqui: vai para o destino Empresa, com abas, na v0.0.7 — juntá-la
/// agora era construir a página unificada que ficou explicitamente de fora.
Future<void> mostrarPerfil(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const PerfilPopup(),
);

/// Há sessão para terminar?
///
/// Função pura porque o `SupabaseConfig.enabled` é constante de compilação: nos
/// testes é sempre `false`, e sem isto o caminho "com sessão" ficava por cobrir.
/// É o mesmo padrão do `podeEliminarMaquinas`.
bool podeTerminarSessao({
  required bool comSupabase,
  required bool comUtilizador,
}) => comSupabase && comUtilizador;

class PerfilPopup extends ConsumerWidget {
  const PerfilPopup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(operationsProvider);
    final acesso = ref.watch(estadoAcessoProvider).valueOrNull;
    final utilizador = SupabaseConfig.enabled
        ? Supabase.instance.client.auth.currentUser
        : null;
    final comSessao = podeTerminarSessao(
      comSupabase: SupabaseConfig.enabled,
      comUtilizador: utilizador != null,
    );
    final cores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final nomeDaConta = utilizador?.userMetadata?['nome'] as String?;
    final nome = nomeDaConta?.trim().isNotEmpty == true
        ? nomeDaConta!.trim()
        : estado.ownerName?.trim().isNotEmpty == true
        ? estado.ownerName!.trim()
        // Sem nome de responsável, o email identifica melhor do que "Gestor".
        : utilizador?.email ?? 'Gestor';

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 380,
          maxHeight: MediaQuery.sizeOf(context).height - 24,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _Avatar(nome: nome),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nome, style: textos.titleMedium),
                        if (estado.companyName.trim().isNotEmpty)
                          Text(
                            estado.companyName.trim(),
                            style: textos.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ChipDeSessao(comSessao: comSessao),
              // O email só se mostra quando existe: em modo de demonstração não
              // há conta, e uma linha vazia com o rótulo "Email" faria parecer
              // que faltava um dado.
              if (utilizador?.email != null) ...[
                const SizedBox(height: 12),
                _Linha(rotulo: 'Email', valor: utilizador!.email!),
              ],
              if (acesso != null) ...[
                const SizedBox(height: 4),
                _Linha(
                  rotulo: 'Perfil',
                  valor: acesso.eGestor ? 'Gestor' : 'Colaborador',
                ),
              ] else if (!SupabaseConfig.enabled) ...[
                const SizedBox(height: 4),
                const _Linha(rotulo: 'Perfil', valor: 'Gestor (demonstração)'),
              ],
              const SizedBox(height: 20),
              if (comSessao) ...[
                OutlinedButton.icon(
                  onPressed: () => _abrirDadosDaEmpresa(context),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar dados da empresa'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _mudarPalavraPasse(context),
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Mudar palavra-passe'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DefinicoesCadeadoPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Cadeado (PIN + biometria)'),
                ),
                if (acesso?.eGestor ?? false) ...[
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _abrirConvites(context),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Convidar membros'),
                  ),
                ],
                const SizedBox(height: 8),
              ],
              if (comSessao)
                OutlinedButton.icon(
                  onPressed: () => _terminarSessao(context, ref),
                  icon: Icon(Icons.logout, color: cores.error),
                  label: Text(
                    'Terminar sessão',
                    style: TextStyle(color: cores.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: cores.error),
                  ),
                )
              else
                Text(
                  'Estás em modo demonstração local — não há sessão para '
                  'terminar.',
                  style: textos.bodySmall,
                ),
              const SizedBox(height: 16),
              const _Versao(),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Confirmação antes de sair, e nunca um diálogo preso.
  ///
  /// Depois do `signOut` quem redirecciona é o `AuthGate`, que observa
  /// `onAuthStateChange` — não se chama `Navigator` à mão daqui. O
  /// `invalidate` força o estado de acesso a ser relido, para o gate não
  /// decidir com a adesão antiga em cache.
  void _abrirDadosDaEmpresa(BuildContext context) {
    final navegador = Navigator.of(context, rootNavigator: true);
    navegador.pop();
    navegador.push(
      MaterialPageRoute<void>(builder: (_) => const CompanySettingsPage()),
    );
  }

  Future<void> _mudarPalavraPasse(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const _MudarPalavraPasseDialog(),
  );

  void _abrirConvites(BuildContext context) {
    final navegador = Navigator.of(context, rootNavigator: true);
    navegador.pop();
    navegador.push(
      MaterialPageRoute<void>(builder: (_) => const ConvitesScreen()),
    );
  }

  Future<void> _terminarSessao(BuildContext context, WidgetRef ref) async {
    final confirmado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Terminar sessão?'),
        content: const Text(
          'Vais voltar ao ecrã de entrada. Os dados guardados neste '
          'dispositivo mantêm-se e podes voltar a entrar quando quiseres.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Terminar sessão'),
          ),
        ],
      ),
    );
    if (confirmado != true || !context.mounted) return;
    try {
      await ref.read(acessoServiceProvider).terminarSessao();
      ref.invalidate(estadoAcessoProvider);
      if (context.mounted) Navigator.pop(context);
    } catch (_) {
      // Falhar a sair não pode deixar o utilizador encalhado num diálogo
      // estático sem explicação.
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível terminar sessão. Tenta outra vez.'),
        ),
      );
    }
  }
}

class _EditarDadosDialog extends StatefulWidget {
  const _EditarDadosDialog({required this.utilizador});
  final User utilizador;

  @override
  State<_EditarDadosDialog> createState() => _EditarDadosDialogState();
}

class _EditarDadosDialogState extends State<_EditarDadosDialog> {
  late final TextEditingController _nome;
  late final TextEditingController _email;
  bool _aGuardar = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _nome = TextEditingController(
      text: (widget.utilizador.userMetadata?['nome'] as String?) ?? '',
    );
    _email = TextEditingController(text: widget.utilizador.email ?? '');
  }

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nome = _nome.text.trim();
    final email = _email.text.trim();
    final erroEmail = AuthRules.validarEmail(email);
    if (nome.isEmpty || erroEmail != null) {
      setState(() => _erro = nome.isEmpty ? 'Indica o teu nome.' : erroEmail);
      return;
    }
    setState(() {
      _aGuardar = true;
      _erro = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          email: email == widget.utilizador.email ? null : email,
          data: {...?widget.utilizador.userMetadata, 'nome': nome},
        ),
      );
      if (mounted) Navigator.pop(context);
    } on AuthException catch (erro) {
      if (mounted) setState(() => _erro = AuthRules.mensagemSegura(erro.code));
    } catch (_) {
      if (mounted) setState(() => _erro = 'Não foi possível guardar os teus dados.');
    } finally {
      if (mounted) setState(() => _aGuardar = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Editar dados'),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nome,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          if (_erro != null) ...[
            const SizedBox(height: 12),
            Text(_erro!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: _aGuardar ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(onPressed: _aGuardar ? null : _guardar, child: Text(_aGuardar ? 'A guardar…' : 'Guardar')),
    ],
  );
}

class _MudarPalavraPasseDialog extends StatefulWidget {
  const _MudarPalavraPasseDialog();

  @override
  State<_MudarPalavraPasseDialog> createState() => _MudarPalavraPasseDialogState();
}

class _MudarPalavraPasseDialogState extends State<_MudarPalavraPasseDialog> {
  final _nova = TextEditingController();
  final _confirmacao = TextEditingController();
  bool _aGuardar = false;
  String? _erro;

  @override
  void dispose() {
    _nova.dispose();
    _confirmacao.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final erro = AuthRules.validarPalavraPasse(_nova.text);
    if (erro != null || _nova.text != _confirmacao.text) {
      setState(() => _erro = erro ?? 'As palavras-passe não coincidem.');
      return;
    }
    setState(() {
      _aGuardar = true;
      _erro = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _nova.text),
      );
      if (mounted) Navigator.pop(context);
    } on AuthException catch (erro) {
      if (mounted) setState(() => _erro = AuthRules.mensagemSegura(erro.code));
    } catch (_) {
      if (mounted) setState(() => _erro = 'Não foi possível mudar a palavra-passe.');
    } finally {
      if (mounted) setState(() => _aGuardar = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Mudar palavra-passe'),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _nova, obscureText: true, decoration: const InputDecoration(labelText: 'Nova palavra-passe')),
          const SizedBox(height: 12),
          TextField(controller: _confirmacao, obscureText: true, decoration: const InputDecoration(labelText: 'Confirmar palavra-passe')),
          if (_erro != null) ...[
            const SizedBox(height: 12),
            Text(_erro!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: _aGuardar ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(onPressed: _aGuardar ? null : _guardar, child: Text(_aGuardar ? 'A guardar…' : 'Atualizar')),
    ],
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.nome});
  final String nome;

  /// Iniciais em vez de fotografia: escolher e carregar foto é fluxo próprio, e
  /// duas letras identificam quem está ligado sem pedir nada a ninguém.
  String get _iniciais {
    final partes = nome
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '';
    if (partes.length == 1) return partes.first.characters.first.toUpperCase();
    return (partes.first.characters.first + partes.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cores.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: _iniciais.isEmpty
          ? Icon(Icons.person_outline, color: cores.onPrimaryContainer)
          : Text(
              _iniciais,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: cores.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

class _ChipDeSessao extends StatelessWidget {
  const _ChipDeSessao({required this.comSessao});
  final bool comSessao;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Chip(
      visualDensity: VisualDensity.compact,
      label: Text(comSessao ? 'SESSÃO ACTIVA' : 'MODO DEMONSTRAÇÃO'),
      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      backgroundColor: comSessao
          ? const Color(0xFFDCF3E3)
          : const Color(0xFFE7E9EB),
      side: BorderSide.none,
    ),
  );
}

class _Linha extends StatelessWidget {
  const _Linha({required this.rotulo, required this.valor});
  final String rotulo, valor;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 64,
        child: Text(rotulo, style: Theme.of(context).textTheme.bodySmall),
      ),
      Expanded(
        child: Text(valor, style: Theme.of(context).textTheme.bodyMedium),
      ),
    ],
  );
}

/// Versão da app, discreta. Serve para o Cesar saber o que está instalado quando
/// alguém lhe descreve um problema ao telefone.
class _Versao extends StatelessWidget {
  const _Versao();

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
    future: PackageInfo.fromPlatform(),
    builder: (context, snapshot) {
      final versao = snapshot.data?.version;
      return Text(
        versao == null ? '' : 'Punho v$versao',
        style: Theme.of(context).textTheme.bodySmall,
      );
    },
  );
}
