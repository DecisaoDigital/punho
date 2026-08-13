import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cadeado_service.dart';

/// Página de definições do cadeado local.
///
/// - Definir/alterar PIN
/// - Threshold em minutos (Nunca / Sempre / 1 / 2 / 5 / 15 / 30)
/// - Activar/desactivar biometria
/// - Bloquear agora (útil para testar)
class DefinicoesCadeadoPage extends ConsumerStatefulWidget {
  const DefinicoesCadeadoPage({super.key});

  @override
  ConsumerState<DefinicoesCadeadoPage> createState() =>
      _DefinicoesCadeadoPageState();
}

class _DefinicoesCadeadoPageState extends ConsumerState<DefinicoesCadeadoPage> {
  bool _temPin = false;
  bool _bioDisponivel = false;
  bool _bioActivada = true;
  int _threshold = CadeadoService.thresholdDefault;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final svc = ref.read(cadeadoServiceProvider);
    final t = await Future.wait([
      svc.temPinDefinido(),
      svc.biometriaDisponivelNoDispositivo(),
      svc.biometriaActivada(),
      svc.thresholdMinutos(),
    ]);
    if (!mounted) return;
    setState(() {
      _temPin = t[0] as bool;
      _bioDisponivel = t[1] as bool;
      _bioActivada = t[2] as bool;
      _threshold = t[3] as int;
      _carregando = false;
    });
  }

  Future<void> _definirOuMudarPin() async {
    final eraNovo = !_temPin;
    final novo = await Navigator.of(context).push<String?>(
      MaterialPageRoute(builder: (_) => const DefinirPinScreen()),
    );
    if (novo == null || novo.isEmpty) return;
    await ref.read(cadeadoServiceProvider).guardarPin(novo);
    if (!mounted) return;
    setState(() => _temPin = true);

    // Primeira definicao + biometria disponivel: perguntar explicitamente,
    // em vez de activar sem avisar. A escolha grava-se no SharedPreferences,
    // portanto so aparece uma vez.
    if (eraNovo && _bioDisponivel) {
      final querBiometria = await showDialog<bool>(
        context: context,
        // Sem saída pelo lado: a escolha grava-se e o diálogo só aparece uma
        // vez, portanto um toque fora da caixa desligava a biometria para
        // sempre — sem o utilizador perceber que tinha decidido alguma coisa.
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Usar biometria?'),
          content: const Text(
            'Além do PIN, podes desbloquear com a impressão digital ou o '
            'rosto. É mais rápido no dia-a-dia. O PIN continua a servir de '
            'alternativa.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Só PIN'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sim, usar biometria'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      // `null` só chega aqui se o diálogo for fechado pelo botão de voltar do
      // Android. Nesse caso não se grava nada — volta a perguntar da próxima —
      // em vez de tratar "não respondi" como "não quero".
      if (querBiometria != null) {
        await ref
            .read(cadeadoServiceProvider)
            .setBiometriaActivada(querBiometria);
        if (!mounted) return;
        setState(() => _bioActivada = querBiometria);
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('PIN definido.')));
  }

  Future<void> _apagarPin() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar cadeado?'),
        content: const Text(
          'Sem PIN o cadeado fica desactivado. Podes voltar a activá-lo em '
          'qualquer momento aqui.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(cadeadoServiceProvider).apagarPin();
    if (!mounted) return;
    setState(() => _temPin = false);
  }

  Future<void> _mudarThreshold(int? valor) async {
    if (valor == null) return;
    await ref.read(cadeadoServiceProvider).setThresholdMinutos(valor);
    setState(() => _threshold = valor);
  }

  Future<void> _toggleBiometria(bool v) async {
    await ref.read(cadeadoServiceProvider).setBiometriaActivada(v);
    setState(() => _bioActivada = v);
  }

  void _bloquearAgora() {
    ref.read(cadeadoBloqueadoProvider.notifier).state = true;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cadeado')),
    body: _carregando
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                leading: const Icon(Icons.pin_outlined),
                title: Text(_temPin ? 'Alterar PIN' : 'Definir PIN'),
                subtitle: Text(
                  _temPin
                      ? 'PIN de 4-6 dígitos activo.'
                      : 'Sem PIN, o cadeado não está activo.',
                ),
                onTap: _definirOuMudarPin,
              ),
              if (_temPin)
                ListTile(
                  leading: const Icon(
                    Icons.lock_open_outlined,
                    color: Colors.redAccent,
                  ),
                  title: const Text('Desactivar cadeado'),
                  subtitle: const Text('Apaga o PIN.'),
                  onTap: _apagarPin,
                ),
              const Divider(),
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint),
                title: const Text('Biometria'),
                subtitle: Text(
                  _bioDisponivel
                      ? 'Usar impressão digital / rosto para desbloquear.'
                      : 'Não disponível neste dispositivo.',
                ),
                value: _bioActivada && _bioDisponivel,
                onChanged: _bioDisponivel && _temPin ? _toggleBiometria : null,
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'BLOQUEAR APÓS INACTIVIDADE',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final opcao in const [
                (-1, 'Nunca (só ao arrancar a app)'),
                (0, 'Sempre'),
                (1, '1 minuto'),
                (2, '2 minutos (recomendado)'),
                (5, '5 minutos'),
                (15, '15 minutos'),
                (30, '30 minutos'),
              ])
                RadioListTile<int>(
                  title: Text(opcao.$2),
                  value: opcao.$1,
                  // ignore: deprecated_member_use
                  groupValue: _threshold,
                  // ignore: deprecated_member_use
                  onChanged: _temPin ? _mudarThreshold : null,
                ),
              const Divider(),
              if (_temPin)
                ListTile(
                  leading: const Icon(Icons.lock_outlined),
                  title: const Text('Bloquear agora'),
                  onTap: _bloquearAgora,
                ),
            ],
          ),
  );
}

/// O ecrã que pede o PIN duas vezes.
///
/// Público só para se poder medir: não depende do serviço nem de nada que
/// precise de mocks — devolve o PIN pelo `pop` e mais nada. O teste em
/// `test/core/cadeado/definir_pin_cabe_no_ecra_test.dart` monta-o directamente
/// com o teclado aberto e às medidas do Redmi deitado.
class DefinirPinScreen extends StatefulWidget {
  const DefinirPinScreen({super.key});
  @override
  State<DefinirPinScreen> createState() => _DefinirPinScreenState();
}

class _DefinirPinScreenState extends State<DefinirPinScreen> {
  final _pin1 = TextEditingController();
  final _pin2 = TextEditingController();
  String? _erro;

  @override
  void dispose() {
    _pin1.dispose();
    _pin2.dispose();
    super.dispose();
  }

  void _validar() {
    if (_pin1.text.length < 4 || _pin1.text.length > 6) {
      setState(() => _erro = 'PIN deve ter 4 a 6 dígitos.');
      return;
    }
    if (_pin1.text != _pin2.text) {
      setState(() => _erro = 'Os PINs não coincidem.');
      return;
    }
    Navigator.of(context).pop(_pin1.text);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    // **O «Guardar» vive na barra**, como em todos os outros formulários da app
    // (`EcraDeFormulario.rotuloGuardar`). Em baixo ficava debaixo do teclado, e
    // um botão que só se alcança rolando é um botão que metade das pessoas não
    // encontra. Na barra está sempre à vista, seja qual for a altura do teclado.
    appBar: AppBar(
      title: const Text('Definir PIN'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilledButton(
            onPressed: _validar,
            child: const Text('Guardar'),
          ),
        ),
      ],
    ),
    // **Rola.** O primeiro campo tem `autofocus`, portanto o teclado abre
    // sozinho ao entrar neste ecrã — e deitado o teclado come 200 dos 393 dp
    // que o Redmi tem de altura. Sem isto, o campo de repetir e o «Guardar»
    // ficavam 143 dp abaixo do fundo, sem nada que os fosse buscar: deitado,
    // o cadeado não se conseguia activar de todo.
    body: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: LayoutBuilder(
        builder: (context, restricoes) {
          // Deitado sobram 790 dp de largura e faltam-lhe 143 de altura. Os
          // dois campos passam a lado a lado, que é como o resto da app paga
          // a altura em paisagem — ver `EcraDeFormulario`. Poupa 97 dp e faz
          // caber quase tudo sem rolar; o `SingleChildScrollView` fica de
          // rede, para o teclado que for mais alto do que este.
          final lado = restricoes.maxWidth >= 480;
          final pin = _campoPin(_pin1, 'PIN', autofocus: true);
          final repetir = _campoPin(_pin2, 'Repetir PIN');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('4 a 6 dígitos. Só vive neste dispositivo.'),
              const SizedBox(height: 16),
              if (lado)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: pin),
                    const SizedBox(width: 16),
                    Expanded(child: repetir),
                  ],
                )
              else ...[pin, const SizedBox(height: 12), repetir],
              if (_erro != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_erro!, style: const TextStyle(color: Colors.red)),
                ),
            ],
          );
        },
      ),
    ),
  );

  Widget _campoPin(
    TextEditingController c,
    String label, {
    bool autofocus = false,
  }) => TextField(
    controller: c,
    autofocus: autofocus,
    keyboardType: TextInputType.number,
    obscureText: true,
    maxLength: 6,
    textAlign: TextAlign.center,
    style: const TextStyle(fontSize: 24, letterSpacing: 8),
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(labelText: label, counterText: ''),
  );
}
