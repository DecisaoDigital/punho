import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/operations/operations_controller.dart';
import '../../../domain/models/workforce.dart';
import '../data/pedidos_service.dart';

/// Quem se inscreveu com um convite desta empresa e espera resposta.
///
/// **Aprovar não é só dar acesso.** A pessoa vai trabalhar, e quem trabalha
/// custa dinheiro à empresa e paga impostos — por isso tem de existir na lista
/// de empregados. Um operador aprovado sem ficha é alguém a trabalhar que não
/// custa nada a ninguém, e as contas do negócio ficam a mentir por omissão.
///
/// Daí as duas hipóteses no diálogo, e daí não haver uma terceira que decida
/// sozinha. Adivinhar criava duas fichas da mesma pessoa, ambas com custo,
/// ambas plausíveis, e ninguém dava por isso.
///
/// **E daí a segunda lista.** Recusar era uma porta de sentido único: o pedido
/// ficava `recusado`, e como só há um pedido por pessoa, inscrever-se outra vez
/// também não era saída. Um toque errado — ou alguém que afinal foi mesmo
/// contratado — ficava de fora para sempre. Quem foi decidido aparece agora
/// aqui em baixo, com o caminho de volta à vista.
class PedidosPendentesScreen extends ConsumerWidget {
  const PedidosPendentesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedidos = ref.watch(pedidosPendentesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pedidos de acesso')),
      body: pedidos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Aviso(
          icone: Icons.cloud_off,
          titulo: 'Não consegui ler os pedidos.',
          detalhe: 'Verifique a ligação e volte a tentar.',
          aoTentar: () => ref.invalidate(pedidosPendentesProvider),
        ),
        data: (lista) => ListView(
          children: [
            if (lista.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: _Aviso(
                  icone: Icons.inbox_outlined,
                  titulo: 'Ninguém à espera.',
                  detalhe:
                      'Quando alguém se inscrever com um convite seu, aparece '
                      'aqui para autorizar.',
                ),
              )
            else
              for (final pedido in lista) ...[
                _LinhaDePedido(pedido: pedido),
                const Divider(height: 1),
              ],
            const _JaDecididos(),
          ],
        ),
      ),
    );
  }
}

/// Quem já teve resposta, e o que ainda se pode fazer sobre isso.
///
/// Fica em baixo e recolhido: no dia-a-dia o que interessa é a fila de cima. É
/// aqui que se corrige um engano — devolver à fila quem foi recusado, tirar o
/// acesso a quem saiu da empresa.
class _JaDecididos extends ConsumerWidget {
  const _JaDecididos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decididos = ref.watch(pedidosDecididosProvider);

    return decididos.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (lista) => lista.isEmpty
          ? const SizedBox.shrink()
          : ExpansionTile(
              title: const Text('Já decididos'),
              subtitle: Text('${lista.length} — para corrigir um engano'),
              children: [
                for (final p in lista) _LinhaDecidida(pedido: p),
              ],
            ),
    );
  }
}

class _LinhaDecidida extends ConsumerStatefulWidget {
  const _LinhaDecidida({required this.pedido});
  final PedidoDecidido pedido;

  @override
  ConsumerState<_LinhaDecidida> createState() => _LinhaDecididaState();
}

class _LinhaDecididaState extends ConsumerState<_LinhaDecidida> {
  bool _ocupado = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    return ListTile(
      title: Text(p.comoSeChama),
      subtitle: Text('${p.email} · ${p.comoSeLe}'),
      trailing: _ocupado
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : p.estaDeFora
          // Reabrir devolve à fila de cima — não dá acesso por si só. Quem o
          // dá é a aprovação que vem a seguir, com a escolha da ficha à frente.
          ? TextButton(
              onPressed: () => _correr(
                (s) => s.reabrir(p.id),
                'Voltou à lista de espera. Aprove-o em cima.',
              ),
              child: const Text('Voltar a considerar'),
            )
          : p.temAcesso
          ? TextButton(
              onPressed: () => _confirmarRevogacao(p),
              child: const Text('Retirar acesso'),
            )
          : null,
    );
  }

  Future<void> _confirmarRevogacao(PedidoDecidido p) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: Text('Retirar o acesso a ${p.comoSeChama}?'),
        content: const Text(
          'Deixa de poder entrar na app. A ficha de empregado mantém-se, com '
          'o que já trabalhou — e o acesso pode ser devolvido aqui mesmo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Não'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );
    if (confirmou == true) {
      await _correr((s) => s.revogar(p.id), 'Acesso retirado.');
    }
  }

  Future<void> _correr(
    Future<void> Function(PedidosService) accao,
    String recado,
  ) async {
    setState(() => _ocupado = true);
    try {
      await accao(ref.read(pedidosServiceProvider));
      ref
        ..invalidate(pedidosDecididosProvider)
        ..invalidate(pedidosPendentesProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(recado)));
      }
    } on PostgrestException catch (e) {
      // O servidor escreve as recusas em português e já pensadas para quem as
      // lê — mostrá-las é melhor do que traduzir aqui por outras palavras.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.code == 'P0001'
                  ? e.message
                  : 'Não consegui. O servidor respondeu: ${e.message}',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não consegui falar com o servidor.')),
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }
}

class _LinhaDePedido extends ConsumerWidget {
  const _LinhaDePedido({required this.pedido});
  final PedidoPendente pedido;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    title: Text(pedido.comoSeChama),
    subtitle: Text(
      pedido.nifDeclarado == null
          ? pedido.email
          : '${pedido.email} · contribuinte ${pedido.nifDeclarado}',
    ),
    trailing: FilledButton(
      onPressed: () => _decidir(context, ref),
      child: const Text('Decidir'),
    ),
  );

  Future<void> _decidir(BuildContext context, WidgetRef ref) async {
    final mudou = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoDeDecisao(pedido: pedido),
    );
    // As duas listas mexem-se ao mesmo tempo: quem sai da fila de cima entra
    // no arquivo de baixo.
    if (mudou == true) {
      ref
        ..invalidate(pedidosPendentesProvider)
        ..invalidate(pedidosDecididosProvider);
    }
  }
}

class _DialogoDeDecisao extends ConsumerStatefulWidget {
  const _DialogoDeDecisao({required this.pedido});
  final PedidoPendente pedido;

  @override
  ConsumerState<_DialogoDeDecisao> createState() => _DialogoDeDecisaoState();
}

class _DialogoDeDecisaoState extends ConsumerState<_DialogoDeDecisao> {
  /// `true` = criar ficha nova. Começa assim porque é o caso mais comum — quem
  /// se inscreve pela app do operador costuma ser contratação recente.
  bool _fichaNova = true;
  String? _colaboradorId;
  bool _ocupado = false;
  String? _erro;

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(operationsProvider);
    // Só fichas por ligar: uma ficha já ligada a outra conta não é uma escolha
    // — o servidor recusava-a, e oferecê-la era convidar ao erro.
    final porLigar = estado.collaborators
        .where((c) => !c.archived)
        .toList(growable: false);

    return AlertDialog(
      title: Text(widget.pedido.comoSeChama),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.pedido.email),
            if (widget.pedido.nifDeclarado != null)
              Text('Contribuinte declarado: ${widget.pedido.nifDeclarado}'),
            const SizedBox(height: 16),
            const Text('Ficha de empregado'),
            RadioGroup<bool>(
              groupValue: _fichaNova,
              onChanged: (bool? v) {
                if (_ocupado) return;
                setState(() => _fichaNova = v ?? true);
              },
              child: Column(
                children: [
                  const RadioListTile<bool>(
                    value: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Criar ficha nova'),
                    subtitle: Text('Custo por apurar — preenche-se depois.'),
                  ),
                  RadioListTile<bool>(
                    value: false,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Já está na lista'),
                    subtitle: porLigar.isEmpty
                        ? const Text('Ainda não há empregados na lista.')
                        : null,
                  ),
                ],
              ),
            ),
            if (!_fichaNova && porLigar.isNotEmpty)
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _colaboradorId,
                decoration: const InputDecoration(labelText: 'Quem é'),
                items: [
                  // `c.id` é o id **local** da ficha, o que a app lhe deu.
                  // Ia direito a um parâmetro `uuid` e o servidor respondia
                  // `22P02` — esta hipótese nunca funcionou desde que nasceu.
                  // Quem traduz o id local para o da tabela é o servidor, que
                  // é quem tem a fórmula; aqui manda-se o que a app conhece.
                  for (final Collaborator c in porLigar)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: _ocupado
                    ? null
                    : (v) => setState(() => _colaboradorId = v),
              ),
            if (_erro != null) ...[
              const SizedBox(height: 12),
              Text(
                _erro!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _ocupado ? null : () => Navigator.of(context).pop(false),
          child: const Text('Fechar'),
        ),
        TextButton(
          onPressed: _ocupado ? null : _recusar,
          child: const Text('Recusar'),
        ),
        FilledButton(
          onPressed: _ocupado || !_podeAprovar ? null : _aprovar,
          child: const Text('Aprovar'),
        ),
      ],
    );
  }

  /// Ligar sem dizer a quem não é uma decisão — é meia. O botão fica desligado
  /// em vez de aprovar com a escolha por fazer.
  bool get _podeAprovar => _fichaNova || _colaboradorId != null;

  Future<void> _aprovar() => _correr(
    () => ref
        .read(pedidosServiceProvider)
        .aprovar(
          widget.pedido.id,
          colaboradorId: _fichaNova ? null : _colaboradorId,
        ),
  );

  Future<void> _recusar() =>
      _correr(() => ref.read(pedidosServiceProvider).recusar(widget.pedido.id));

  Future<void> _correr(Future<void> Function() accao) async {
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      await accao();
      if (mounted) Navigator.of(context).pop(true);
    } on PostgrestException catch (e) {
      // O servidor escreve as recusas em português e já pensadas para quem as
      // lê — o limite de operadores, por exemplo, diz o que fazer a seguir.
      if (mounted) {
        setState(
          () => _erro = e.code == 'P0001'
              ? e.message
              : 'Não consegui decidir. O servidor respondeu: ${e.message}',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _erro = 'Não consegui falar com o servidor.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.icone,
    required this.titulo,
    required this.detalhe,
    this.aoTentar,
  });

  final IconData icone;
  final String titulo, detalhe;
  final VoidCallback? aoTentar;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 48),
          const SizedBox(height: 16),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(detalhe, textAlign: TextAlign.center),
          if (aoTentar != null) ...[
            const SizedBox(height: 24),
            FilledButton(
              onPressed: aoTentar,
              child: const Text('Tentar outra vez'),
            ),
          ],
        ],
      ),
    ),
  );
}
