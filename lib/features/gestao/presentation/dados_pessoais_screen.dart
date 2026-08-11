import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/dados_pessoais_service.dart';

/// «Apaguem os meus dados» — e o que é preciso para responder que sim.
///
/// **Porque é que se procura antes de apagar.** A mesma pessoa pode estar na
/// empresa mais do que uma vez: um cliente que se cadastrou duas vezes, um
/// contacto que depois virou cliente. Na prova de 11/8 havia três fichas com o
/// mesmo nome. Apagar uma e dizer que estava feito era assinar uma coisa falsa
/// — por isso este ecrã começa pela procura e mostra **todas** as fichas.
///
/// **O que o apagamento faz.** O nome passa a «Titular apagado» e o contribuinte,
/// telefone, email, morada e notas saem. Saem também dos sítios onde o nome
/// tinha sido copiado — dentro de cada reserva. O que fica é o trabalho: as
/// reservas, os valores e as datas continuam lá, agora sem dizerem de quem
/// eram. É o que a lei fiscal obriga a guardar e o RGPD não manda apagar.
///
/// **Não tem volta.** Não há «desfazer»: o que se apaga não está guardado em
/// lado nenhum para voltar. Daí a confirmação escrever o nome de quem vai
/// desaparecer.
class DadosPessoaisScreen extends ConsumerStatefulWidget {
  const DadosPessoaisScreen({super.key});

  @override
  ConsumerState<DadosPessoaisScreen> createState() =>
      _DadosPessoaisScreenState();
}

class _DadosPessoaisScreenState extends ConsumerState<DadosPessoaisScreen> {
  final _procura = TextEditingController();

  @override
  void dispose() {
    _procura.dispose();
    super.dispose();
  }

  void _procurar() =>
      ref.read(termoDeProcuraProvider.notifier).state = _procura.text;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final fichas = ref.watch(fichasEncontradasProvider);
    final procurou = ref.watch(termoDeProcuraProvider).trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Apagar dados de uma pessoa')),
      // Lista de raiz: em paisagem com o teclado aberto sobram 192 dp de
      // altura, e um ecrã que não rola aí não se usa.
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'Procure por nome, contribuinte, telefone ou email. A mesma '
            'pessoa pode ter mais do que uma ficha — apareceriam todas aqui, '
            'e é preciso apagar cada uma.',
            style: textos.bodyMedium,
          ),
          const SizedBox(height: 16),
          Semantics(
            textField: true,
            label: 'Quem procurar',
            child: TextField(
              controller: _procura,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _procurar(),
              decoration: InputDecoration(
                labelText: 'Nome, contribuinte, telefone ou email',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: _procurar,
                  icon: const Icon(Icons.search),
                  tooltip: 'Procurar',
                  iconSize: 24,
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (!procurou)
            const _Nota(
              icone: Icons.person_search_outlined,
              titulo: 'Comece por procurar.',
              detalhe:
                  'Nada é apagado sem primeiro ver quantas fichas existem '
                  'dessa pessoa.',
            )
          else
            fichas.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => _Nota(
                icone: Icons.cloud_off,
                titulo: 'Não consegui procurar.',
                detalhe: e is PostgrestException
                    ? e.message
                    : 'Verifique a ligação e volte a tentar.',
              ),
              data: (lista) => _Resultados(lista: lista),
            ),
          const SizedBox(height: 24),
          const _JaApagados(),
        ],
      ),
    );
  }
}

class _Resultados extends StatelessWidget {
  const _Resultados({required this.lista});
  final List<FichaDeTitular> lista;

  @override
  Widget build(BuildContext context) {
    if (lista.isEmpty) {
      return const _Nota(
        icone: Icons.search_off,
        titulo: 'Ninguém com esses dados.',
        detalhe:
            'Quem já foi apagado não aparece por nome — o nome deixou de lá '
            'estar.',
      );
    }

    final porApagar = lista.where((f) => !f.jaApagado).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // O aviso que evita a resposta falsa: se são três fichas, apagar uma
        // não é ter respondido ao pedido.
        if (porApagar > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _Nota(
              icone: Icons.warning_amber_outlined,
              titulo: '$porApagar fichas desta pessoa.',
              detalhe:
                  'Para o pedido ficar respondido, tem de apagar as '
                  '$porApagar.',
              acentuada: true,
            ),
          ),
        for (final ficha in lista) _LinhaDeFicha(ficha: ficha),
      ],
    );
  }
}

class _LinhaDeFicha extends ConsumerStatefulWidget {
  const _LinhaDeFicha({required this.ficha});
  final FichaDeTitular ficha;

  @override
  ConsumerState<_LinhaDeFicha> createState() => _LinhaDeFichaState();
}

class _LinhaDeFichaState extends ConsumerState<_LinhaDeFicha> {
  bool _ocupado = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.ficha;
    final cores = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          f.comoSeChama,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            f.oQueE,
            if (f.contacto?.isNotEmpty ?? false) f.contacto!,
            '${f.revisoes} ${f.revisoes == 1 ? 'alteração' : 'alterações'}',
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _ocupado
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : f.jaApagado
            ? Chip(
                label: const Text('Já apagado'),
                backgroundColor: cores.surfaceContainerHighest,
              )
            : Semantics(
                button: true,
                label: 'Apagar os dados de ${f.comoSeChama}',
                child: TextButton(
                  onPressed: _confirmar,
                  style: TextButton.styleFrom(
                    foregroundColor: cores.error,
                    minimumSize: const Size(88, 48),
                  ),
                  child: const Text('Apagar'),
                ),
              ),
      ),
    );
  }

  Future<void> _confirmar() async {
    final f = widget.ficha;
    final motivo = TextEditingController();
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: Text('Apagar os dados de ${f.comoSeChama}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sai o nome, o contribuinte, o telefone, o email, a morada e as '
              'notas — desta ficha e das reservas onde o nome tinha sido '
              'copiado.\n\n'
              'Fica o trabalho: reservas, valores e datas continuam, sem '
              'dizerem de quem eram.\n\n'
              'Não tem volta.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: motivo,
              decoration: const InputDecoration(
                labelText: 'Motivo (fica no registo)',
                hintText: 'Pedido do titular, 11/08',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Não apagar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirmou != true) {
      motivo.dispose();
      return;
    }

    setState(() => _ocupado = true);
    try {
      final linhas = await ref
          .read(dadosPessoaisServiceProvider)
          .apagar(
            entidade: f.entidade,
            entidadeId: f.entidadeId,
            motivo: motivo.text.trim().isEmpty ? null : motivo.text.trim(),
          );
      ref
        ..invalidate(fichasEncontradasProvider)
        ..invalidate(apagamentosFeitosProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Apagado. $linhas ${linhas == 1 ? 'registo' : 'registos'} '
              'ficaram sem dados pessoais.',
            ),
          ),
        );
      }
    } on PostgrestException catch (e) {
      // O servidor recusa em português e já pensado para quem lê — mostrar a
      // frase dele é melhor do que inventar outra aqui.
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não consegui falar com o servidor.')),
        );
      }
    } finally {
      motivo.dispose();
      if (mounted) setState(() => _ocupado = false);
    }
  }
}

/// O que já foi apagado. É isto que se mostra a quem pediu — e a quem
/// perguntar porque é que uma ficha ficou sem nome.
class _JaApagados extends ConsumerWidget {
  const _JaApagados();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feitos = ref.watch(apagamentosFeitosProvider);

    return feitos.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (lista) => lista.isEmpty
          ? const SizedBox.shrink()
          : ExpansionTile(
              title: const Text('Apagamentos feitos'),
              subtitle: Text('${lista.length} — o registo do que se apagou'),
              children: [
                for (final a in lista)
                  ListTile(
                    dense: true,
                    title: Text(
                      '${_comoSeLe(a.entidade)} · ${a.linhas} '
                      '${a.linhas == 1 ? 'registo' : 'registos'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        _quando(a.feitoEm),
                        if (a.motivo?.isNotEmpty ?? false) a.motivo!,
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
    );
  }

  static String _comoSeLe(String entidade) => switch (entidade) {
    'customer' => 'Cliente',
    'collaborator' => 'Empregado',
    'lead' => 'Contacto',
    _ => entidade,
  };

  static String _quando(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year} às '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

class _Nota extends StatelessWidget {
  const _Nota({
    required this.icone,
    required this.titulo,
    required this.detalhe,
    this.acentuada = false,
  });

  final IconData icone;
  final String titulo, detalhe;
  final bool acentuada;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final cor = acentuada ? cores.error : cores.onSurfaceVariant;

    return Semantics(
      label: '$titulo $detalhe',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: acentuada
              ? cores.errorContainer.withValues(alpha: 0.35)
              : cores.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, color: cor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: textos.titleSmall?.copyWith(color: cor),
                  ),
                  const SizedBox(height: 4),
                  Text(detalhe, style: textos.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
