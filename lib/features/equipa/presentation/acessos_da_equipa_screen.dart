import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/funcao_na_equipa.dart';
import '../equipa_providers.dart';

/// Onde o gerente faz de alguém a Secretaria (o terminal do escritório) e escolhe o que ela não vê.
///
/// Só aparecem pessoas que já são gestoras da empresa (entram pelos pedidos de
/// acesso, como gestor). Cada alteração grava logo: não há botão de guardar.
class AcessosDaEquipaScreen extends ConsumerWidget {
  const AcessosDaEquipaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipa = ref.watch(equipaProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Acessos da equipa')),
      body: equipa.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Não consegui ler a equipa.'),
                TextButton(
                  onPressed: () => ref.invalidate(equipaProvider),
                  child: const Text('Tentar outra vez'),
                ),
              ],
            ),
          ),
        ),
        data: (membros) {
          final outros = membros.where((m) => !m.eu).toList();
          if (outros.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Ainda não há mais ninguém na gestão. Quem se inscrever como '
                  'gestor e for aprovado aparece aqui, e podes fazer dessa '
                  'pessoa a Secretaria.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [for (final m in outros) _CartaoDeMembro(membro: m)],
          );
        },
      ),
    );
  }
}

class _CartaoDeMembro extends ConsumerStatefulWidget {
  const _CartaoDeMembro({required this.membro});
  final MembroDaEquipa membro;

  @override
  ConsumerState<_CartaoDeMembro> createState() => _CartaoDeMembroState();
}

class _CartaoDeMembroState extends ConsumerState<_CartaoDeMembro> {
  late bool _administrativa = widget.membro.funcao.eAdministrativa;
  late Set<String> _ocultos = {...widget.membro.funcao.ecrasOcultos};
  bool _aGravar = false;
  String? _erro;

  Future<void> _gravar({
    required bool administrativa,
    required Set<String> ocultos,
  }) async {
    final antesAdministrativa = _administrativa;
    final antesOcultos = _ocultos;
    setState(() {
      _administrativa = administrativa;
      _ocultos = ocultos;
      _aGravar = true;
      _erro = null;
    });
    try {
      await ref
          .read(equipaServiceProvider)
          .definir(
            widget.membro.userId,
            funcao: administrativa ? 'administrativa' : 'gerente',
            ecrasOcultos: ocultos,
          );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _administrativa = antesAdministrativa;
        _ocultos = antesOcultos;
        _erro = 'Não consegui gravar. Tenta outra vez.';
      });
    } finally {
      if (mounted) setState(() => _aGravar = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.membro.email,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('É a Secretaria'),
            subtitle: const Text(
              'Valida as leads quentes e faz as marcações. Tem os mesmos '
              'poderes de um gerente.',
            ),
            value: _administrativa,
            onChanged: _aGravar
                ? null
                : (v) => _gravar(administrativa: v, ocultos: v ? _ocultos : {}),
          ),
          if (_administrativa) ...[
            const Text(
              'O que ela vê na barra lateral',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            for (final e in ecrasEscondiveis)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(e.label),
                value: !_ocultos.contains(e.name),
                onChanged: _aGravar
                    ? null
                    : (v) => _gravar(
                        administrativa: true,
                        ocultos: v == true
                            ? ({..._ocultos}..remove(e.name))
                            : {..._ocultos, e.name},
                      ),
              ),
          ],
          if (_erro != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _erro!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
  );
}
