import '../../../core/orientacao/orientacao_do_contexto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_rules.dart';
import '../acesso_providers.dart';
import '../data/acesso_service.dart';

/// Criação de conta. Nunca cria empresa nem adesão — só deixa o pedido
/// registado. Quem decide é o Decisão Digital Control, à mão.
class RegistoScreen extends ConsumerStatefulWidget {
  const RegistoScreen({super.key, this.aoVoltarParaLogin});

  /// Chamado depois de a conta ser criada com sucesso, para o ecrã de auth
  /// voltar ao início de sessão.
  final VoidCallback? aoVoltarParaLogin;

  @override
  ConsumerState<RegistoScreen> createState() => _RegistoScreenState();
}

class _RegistoScreenState extends ConsumerState<RegistoScreen> {
  @override
  void initState() {
    super.initState();
    OrientacaoDoContexto.portraitJa();
  }

  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _palavraPasse = TextEditingController();
  final _empresa = TextEditingController();
  final _convite = TextEditingController();
  String _perfil = 'colaborador';
  bool _ocupado = false;
  String? _erro;
  String? _sucesso;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _palavraPasse.dispose();
    _empresa.dispose();
    _convite.dispose();
    super.dispose();
  }

  /// Validação local mínima. O servidor volta a validar tudo.
  String? _validar() {
    if (_nome.text.trim().isEmpty) return 'Indica o teu nome.';
    final email = AuthRules.validarEmail(_email.text);
    if (email != null) return email;
    final palavraPasse = AuthRules.validarPalavraPasse(_palavraPasse.text);
    if (palavraPasse != null) return palavraPasse;
    return AuthRules.validarNomeEmpresa(_empresa.text);
  }

  Future<void> _submeter() async {
    final erroLocal = _validar();
    if (erroLocal != null) {
      setState(() => _erro = erroLocal);
      return;
    }
    setState(() {
      _ocupado = true;
      _erro = null;
      _sucesso = null;
    });

    final servico = ref.read(acessoServiceProvider);
    final codigo = _convite.text.trim();
    try {
      // Convite validado antes do signUp: o trigger também recusa um código
      // imprestável, mas em erro do servidor a mensagem que chega à app é
      // genérica. Aqui dá-se a razão concreta.
      if (codigo.isNotEmpty) {
        final validacao = await servico.validarConvite(codigo);
        if (validacao != ValidacaoConvite.valido) {
          if (mounted) {
            setState(() {
              _erro = validacao.mensagem;
              _ocupado = false;
            });
          }
          return;
        }
      }

      await servico.registar(
        email: _email.text.trim(),
        palavraPasse: _palavraPasse.text,
        nome: _nome.text.trim(),
        empresa: _empresa.text.trim(),
        perfil: _perfil,
        codigoConvite: codigo.isEmpty ? null : codigo,
      );
      if (!mounted) return;
      setState(
        () => _sucesso =
            'Conta criada. O acesso fica pendente de aprovação manual — '
            'avisamos assim que estiver activo.',
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => _erro = AuthRules.mensagemSegura(e.code));
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _erro = AuthRules.mensagemSegura(e.code));
    } catch (_) {
      if (mounted) setState(() => _erro = AuthRules.mensagemSegura(null));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Criar conta',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nome,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: _palavraPasse,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Palavra-passe',
                    helperText: 'Pelo menos 8 caracteres.',
                  ),
                ),
                TextField(
                  controller: _empresa,
                  decoration: const InputDecoration(
                    labelText: 'Empresa / organização',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _perfil,
                  decoration: const InputDecoration(
                    labelText: 'Cargo pretendido',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'gestor',
                      child: Text('Gestor'),
                    ),
                    DropdownMenuItem(
                      value: 'colaborador',
                      child: Text('Colaborador'),
                    ),
                  ],
                  onChanged: _ocupado
                      ? null
                      : (v) => setState(() => _perfil = v ?? 'colaborador'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _convite,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Código de convite (opcional)',
                  ),
                ),
                if (_erro != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _erro!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (_sucesso != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_sucesso!),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _ocupado ? null : _submeter,
                  child: Text(_ocupado ? 'A criar...' : 'Pedir acesso'),
                ),
                if (widget.aoVoltarParaLogin != null)
                  TextButton(
                    onPressed: _ocupado ? null : widget.aoVoltarParaLogin,
                    child: const Text('Já tenho conta'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
