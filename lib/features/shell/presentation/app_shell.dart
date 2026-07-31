import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/orientacao/orientacao_do_contexto.dart';
import '../../../core/navigation/app_destination.dart';
import '../../../core/navigation/navigation_controller.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../core/session/demo_session.dart';
import '../../../core/theme/punho_theme.dart';
import '../../../shared/widgets/brand_lockup.dart';
import '../../../shared/widgets/versao_app.dart';
import '../../collaborator/presentation/collaborator_shell.dart';
import '../../conta/presentation/perfil_popup.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../empresa/presentation/empresa_page.dart';
import '../../licenca/presentation/licenca_banner.dart';
import '../../operations/presentation/operational_pages.dart';
import '../../tarefas/data/tarefas_service.dart';
import '../../tarefas/presentation/tarefas_page.dart';
import '../../workforce/presentation/workforce_pages.dart';

/// Chave da barra lateral. Existe porque os rótulos dos destinos ("Máquinas")
/// repetem-se nos nomes dos slides do painel: sem ela os testes não sabiam
/// distinguir o rótulo da barra do nome do slide.
const chaveDaBarraLateral = Key('barra-lateral');

/// O avatar do fundo da barra lateral, que abre o Perfil. Tem chave própria
/// porque há outros ícones de pessoa no ecrã e os testes precisam deste.
const chaveDoAvatarDoPerfil = Key('avatar-do-perfil');

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    // O único ecrã da app que leva landscape (Decisão 13). Aqui e em mais
    // nenhum: o painel são cinco slides de quatro KPIs lado a lado, e em
    // portrait não caberia sem espremer os números até não se lerem.
    OrientacaoDoContexto.landscapeJa();
  }

  @override
  Widget build(BuildContext context) {
    final operational = ref.watch(operationsProvider);
    final session = ref.watch(demoSessionProvider);
    if (!operational.onboarded) return const OnboardingPage();
    // Só o modo de demonstração local decide o perfil por aqui. Com Supabase
    // ligado quem escolhe a shell é o AcessoGate, a partir do perfil aprovado
    // em punho_membros — a esta altura já se sabe que é gestor.
    if (!SupabaseConfig.enabled && !session.isManager) {
      return const CollaboratorShell();
    }

    final destination = ref.watch(navigationProvider);
    final destinations = visibleOperationalDestinations(operational);
    final isDesktop = MediaQuery.sizeOf(context).width >= 680;
    // O aviso de licença fica acima do conteúdo para aparecer em todos os
    // ecrãs, e não só no painel de gestão. Encolhe a zero quando está tudo bem.
    final content = Column(
      children: [
        const LicencaBanner(),
        Expanded(
          // A moldura da shell já protege a área das notificações. Os ecrãs
          // podem começar logo abaixo dela, sem cada um reservar o topo outra
          // vez através de um SafeArea próprio.
          child: MediaQuery.removePadding(
            context: context,
            removeTop: isDesktop,
            child: _DestinationContent(destination: destination),
          ),
        ),
      ],
    );

    // Sem widget de bloqueio à volta: a orientação é decidida no `initState`,
    // uma vez, em vez de ser reaplicada a cada rebuild do layout.
    if (isDesktop) {
      // Em Android landscape, a área das notificações pode desenhar-se por
      // cima do Scaffold. A faixa é deliberadamente parte do layout (e não
      // apenas `statusBarColor`), para nunca deixar ícones claros sobre o
      // fundo claro do painel.
      final topInset = MediaQuery.paddingOf(context).top;
      // A faixa acompanha a área das notificações e nada mais: 2 dp a menos
      // que a margem segura, que é o máximo que se pode aparar sem ficar
      // conteúdo claro por baixo dos ícones do sistema.
      //
      // **Não encolhe mais.** Em Android recente o `statusBarColor` já não é
      // respeitado — é esta faixa desenhada no layout que põe as notificações
      // em fundo escuro. Encolhê-la é perder exactamente o que ela existe para
      // dar. Quem procurar aqui altura para poupar, procure noutro sítio.
      // Com tecto. Em landscape, um telemóvel com recorte de câmara reporta uma
      // margem segura bem maior do que a barra de estado precisa, e a faixa
      // ficava grossa — foi o que o Cesar viu. 24 dp chega para os ícones do
      // sistema em qualquer telemóvel.
      final semExcesso = topInset > 2 ? topInset - 2 : topInset;
      final alturaDaMoldura = semExcesso > 24.0 ? 24.0 : semExcesso;
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: PunhoTheme.navyDeep,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Scaffold(
          body: Column(
            children: [
              if (alturaDaMoldura > 0)
                SizedBox(
                  height: alturaDaMoldura,
                  child: const ColoredBox(color: PunhoTheme.navyDeep),
                ),
              Expanded(
                child: Row(
                  children: [
                    _Sidebar(destinations: destinations, selected: destination),
                    Expanded(child: content),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const BrandLockup(compact: true),
        actions: [
          if (!SupabaseConfig.enabled) const _ProfileSelector(),
          IconButton(
            tooltip: 'Conta',
            icon: const Icon(Icons.person_outline_rounded),
            onPressed: () => mostrarPerfil(context),
          ),
        ],
      ),
      drawer: Drawer(
        child: _MobileMenu(destinations: destinations, selected: destination),
      ),
      body: content,
    );
  }
}

class _ProfileSelector extends ConsumerWidget {
  const _ProfileSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(demoSessionProvider).role;
    return DropdownButton<DemoRole>(
      value: role,
      underline: const SizedBox(),
      dropdownColor: Theme.of(context).colorScheme.surface,
      items: DemoRole.values
          .map(
            (x) => DropdownMenuItem(
              value: x,
              child: Text(switch (x) {
                DemoRole.manager => 'Gestor',
                DemoRole.collaboratorA => 'Colaborador A',
                DemoRole.collaboratorB => 'Colaborador B',
              }),
            ),
          )
          .toList(),
      onChanged: (x) => ref.read(demoSessionProvider.notifier).select(x!),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.destinations, required this.selected});
  final List<AppDestination> destinations;
  final AppDestination selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    key: chaveDaBarraLateral,
    // 88 dp em vez de 72: passou a caber o rótulo debaixo do ícone. Com só
    // ícones, o rótulo dependia do tooltip — que num tablet só aparece com
    // toque longo, ou seja não aparece a quem está a aprender a app.
    width: 88,
    color: PunhoTheme.navyDeep,
    child: SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            // Espaço acima e abaixo da marca.
            //
            // Esteve em 4 dp e ficou mal: a marca encostava à moldura escura e
            // o primeiro botão vinha logo a seguir, sem respiro — o Cesar
            // descreveu-o como "um corte rente aos botões" que tirou harmonia à
            // barra. Aqueles 8 dp poupados não valiam a altura que davam.
            //
            // Isto é a barra **vertical**. A faixa escura do topo é outra coisa
            // e não encolhe: é ela que põe as notificações em fundo escuro.
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 20),
            child: Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Transform.scale(
                    // Remove a margem branca do ficheiro de conceito sem
                    // alterar o tamanho reservado para a marca.
                    scale: 1.12,
                    child: Image.asset(
                      'assets/brand/punho_elo_operacao_v010.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Labels de secção ("CENTRO DE COMANDO", "OPERAÇÃO") removidos:
          // Cesar validou no smoke que os ícones + rótulos já são suficientes
          // e as labels só ocupavam altura sem valor informativo real.
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final item in destinations)
                  _SidebarItem(
                    item: item,
                    selected: selected == item,
                    onTap: () =>
                        ref.read(navigationProvider.notifier).goTo(item),
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: Color(0xFF203A4D)),
                ),
                const _PerfilSidebarItem(),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PerfilSidebarItem extends StatelessWidget {
  const _PerfilSidebarItem();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: chaveDoAvatarDoPerfil,
        onTap: () => mostrarPerfil(context),
        borderRadius: BorderRadius.circular(10),
        // Sem `const` na moldura: o rótulo da versão lê o `PackageInfo` em
        // runtime, portanto a subárvore deixou de poder ser constante. Cada
        // filho fixo leva o seu `const`.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 22,
                  color: Color(0xFFB7C7D1),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Perfil',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.1,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFB7C7D1),
                  ),
                ),
                const SizedBox(height: 1),
                VersaoApp(
                  formato: (versao) => 'v $versao',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 8,
                    height: 1.0,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF7F98A8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SidebarItem extends ConsumerWidget {
  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppDestination item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Só Tarefas leva contagem. Um badge em cada área deixaria de chamar a
    // atenção a nada.
    final pendentes = item == AppDestination.tasks
        ? ref.watch(contagemTarefasPendentesProvider)
        : 0;
    final urgente =
        item == AppDestination.tasks && ref.watch(tarefasTemUrgenteProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF2B4A5E) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: selected
                  ? const Border(
                      left: BorderSide(color: PunhoTheme.orange, width: 3),
                    )
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              child: SizedBox(
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      children: [
                        Icon(
                          item.icon,
                          size: 22,
                          color: selected
                              ? PunhoTheme.orange
                              : const Color(0xFFB7C7D1),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.1,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: selected
                                ? PunhoTheme.orange
                                : const Color(0xFFB7C7D1),
                          ),
                        ),
                      ],
                    ),
                    if (pendentes > 0)
                      Positioned(
                        top: -2,
                        right: 4,
                        child: _Badge(quantidade: pendentes, urgente: urgente),
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
}

/// Contagem de pendentes. Vermelho só quando há algo urgente — um badge
/// vermelho permanente por causa de uma morada em falta deixa de significar
/// nada.
class _Badge extends StatelessWidget {
  const _Badge({required this.quantidade, required this.urgente});
  final int quantidade;
  final bool urgente;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 16),
    height: 16,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: urgente ? const Color(0xFFE24B4A) : const Color(0xFF4A5C68),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      quantidade > 9 ? '9+' : '$quantidade',
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    ),
  );
}

class _MobileMenu extends ConsumerWidget {
  const _MobileMenu({required this.destinations, required this.selected});
  final List<AppDestination> destinations;
  final AppDestination selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: EdgeInsets.zero,
    children: [
      const DrawerHeader(
        decoration: BoxDecoration(color: PunhoTheme.navyDeep),
        child: Align(alignment: Alignment.centerLeft, child: BrandLockup()),
      ),
      for (final item in destinations)
        ListTile(
          selected: item == selected,
          selectedTileColor: const Color(0xFFFFF1DA),
          leading: Icon(
            item.icon,
            color: item == selected ? PunhoTheme.orange : null,
          ),
          title: Text(item.label),
          onTap: () {
            ref.read(navigationProvider.notifier).goTo(item);
            Navigator.pop(context);
          },
        ),
    ],
  );
}

class _DestinationContent extends StatelessWidget {
  const _DestinationContent({required this.destination});
  final AppDestination destination;

  @override
  Widget build(BuildContext context) {
    if (destination == AppDestination.management) return const DashboardPage();
    if (destination == AppDestination.machines) return const MachinesPage();
    if (destination == AppDestination.clients) return const ClientsPage();
    if (destination == AppDestination.bookings) return const BookingsPage();
    if (destination == AppDestination.tasks) return const TarefasPage();
    if (destination == AppDestination.employees) {
      return const CollaboratorsPage();
    }
    if (destination == AppDestination.empresa) return const EmpresaPage();
    // Finanças e Veículos deixaram de ser destinos da barra, mas quem lá for
    // ter — por uma tarefa antiga, por código que ainda os nomeie — abre a
    // Empresa na aba certa, em vez de encontrar um ecrã vazio.
    final aba = destination.abaDeEmpresa;
    if (aba != null) return EmpresaPage(abaInicial: aba);
    return _EmptyPage(destination: destination);
  }
}

class _EmptyPage extends StatelessWidget {
  const _EmptyPage({required this.destination});
  final AppDestination destination;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            destination.icon,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            destination.label,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Este espaço está preparado para a próxima fase.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
