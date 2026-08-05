import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_rules.dart';
import '../../../core/licenca/machine_id.dart';
import '../acesso_providers.dart';

/// Conta autenticada, sem adesão e **sem pedido nenhum**. Aqui faz-se o pedido.
///
/// Este ecrã existe por causa de um beco encontrado a 5 de Agosto de 2026: o
/// pedido de acesso só nascia no trigger do registo, portanto quem já tinha
/// conta não tinha como o fazer. Uma conta revogada — ou cuja empresa fosse
/// apagada — ficava a ver "Pedido em análise" para sempre, com o Control sem
/// linha nenhuma para aprovar. A app afirmava uma coisa que não era verdade e
/// não dava saída nenhuma.
///
/// A identidade não se escreve aqui. O nome e a empresa são o que a pessoa
/// declara; **quem ela é** vem da sessão, no servidor.
class PedirAcessoScreen extends ConsumerStatefulWidget {
  const PedirAcessoScreen({super.key});

  @override
  ConsumerState<PedirAcessoScreen> createState() => _PedirAcessoScreenState();
}

class _PedirAcessoScreenState extends ConsumerState<PedirAcessoScreen> {
  final _nome = TextEditingController();
  final _empresa = TextEditingController();
  String _perfil = 'gestor';
  bool _ocupado = false;
  String? _erro;

  /// O terminal de onde parte o pedido, resolvido enquanto o formulário se
  /// preenche — fora do caminho de submissão, como no registo. Nulo quando não
  /// se consegue ler, que é preferível a inventar um.
  String? _machineId;

  @override
  void initState() {
    super.initState();
    _resolverMaquina();
  }

  Future<void> _resolverMaquina() async {
    try {
      final id = await resolverMachineId();
      if (mounted) setState(() => _machineId = id);
    } catch (_) {
      // Sem plugins nativos não há máquina para dizer. Não é erro de pedido.
    }
  }

  @override
  void dispose() {
    _nome.dispose();
    _empresa.dispose();
    super.dispose();
  }

  /// Validação local mínima — a do servidor é a que manda.
  String? _validar() {
    if (_nome.text.trim().isEmpty) return 'Indica o teu nome.';
    return AuthRules.validarNomeEmpresa(_empresa.text);
  }

  Future<void> _pedir() async {
    final erro = _validar();
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      await ref
          .read(acessoServiceProvider)
          .pedirAcesso(
            nome: _nome.text.trim(),
            empresa: _empresa.text.trim(),
            perfil: _perfil,
            // O terminal segue pelo mesmo caminho que no registo — é a mesma
            // chave `(machine_id, app)` que identifica um terminal no POS.
            machineId: _machineId,
          );
      if (!mounted) return;
      // Volta a perguntar ao servidor em vez de assumir o que ficou lá: é o
      // mesmo porteiro que decide o ecrã seguinte, agora com o pedido criado.
      ref.invalidate(estadoAcessoProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _erro = AuthRules.mensagemSegura(null);
      });
    }
  }

  @override
  // `SafeArea` como no `LoginScreen` e no `RegistoScreen`: este ecrã é montado
  // pelo `AcessoGate`, sem `AppShell` por cima a descontar a barra de estado
  // (Decisão 8 do padrão visual). Sem ele o título ficava por baixo do relógio.
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.badge_outlined, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Falta pedir acesso',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A tua conta existe, mas não há nenhum pedido de acesso '
                    'associado a ela. Preenche e o pedido segue para aprovação.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nome,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'O teu nome',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _empresa,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Empresa',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _perfil,
                    decoration: const InputDecoration(
                      labelText: 'Entras como',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'gestor', child: Text('Gestor')),
                      DropdownMenuItem(
                        value: 'colaborador',
                        child: Text('Colaborador'),
                      ),
                    ],
                    onChanged: _ocupado
                        ? null
                        : (x) => setState(() => _perfil = x ?? 'gestor'),
                  ),
                  if (_erro != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _erro!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _ocupado ? null : _pedir,
                    child: Text(_ocupado ? 'A enviar…' : 'Pedir acesso'),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _ocupado
                        ? null
                        : () =>
                              ref.read(acessoServiceProvider).terminarSessao(),
                    child: const Text('Terminar sessão'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
