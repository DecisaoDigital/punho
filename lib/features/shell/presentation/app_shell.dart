import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/orientacao/orientacao_do_contexto.dart';
import '../../../core/navigation/app_destination.dart';
import '../../../core/navigation/navigation_controller.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../core/session/demo_session.dart';
import '../../../core/theme/punho_theme.dart';
import '../../../shared/widgets/brand_lockup.dart';
import '../../auth/acesso_providers.dart';
import '../../collaborator/presentation/collaborator_shell.dart';
import '../../conta/presentation/perfil_popup.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../finance/presentation/financas_page.dart';
import '../../gestao/presentation/convites_screen.dart';
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
        Expanded(child: _DestinationContent(destination: destination)),
      ],
    );

    // Sem widget de bloqueio à volta: a orientação é decidida no `initState`,
    // uma vez, em vez de ser reaplicada a cada rebuild do layout.
    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(destinations: destinations, selected: destination),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Punho'),
        actions: [
          if (!SupabaseConfig.enabled) const _ProfileSelector(),
          if (SupabaseConfig.enabled) const _ConvitesButton(),
          if (SupabaseConfig.enabled) const _SignOutButton(),
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

/// Atalho para os convites da empresa. Só aparece a quem está aprovado como
/// gestor — um colaborador não gere acessos.
class _ConvitesButton extends ConsumerWidget {
  const _ConvitesButton({this.onDarkBackground = false});
  final bool onDarkBackground;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gestor =
        ref.watch(estadoAcessoProvider).valueOrNull?.eGestor ?? false;
    if (!gestor) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Convites',
      color: onDarkBackground ? const Color(0xFFB7C5CE) : null,
      icon: const Icon(Icons.person_add_alt),
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const ConvitesScreen())),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Terminar sessão',
    icon: const Icon(Icons.logout),
    onPressed: () => Supabase.instance.client.auth.signOut(),
  );
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: PunhoTheme.orange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pan_tool_alt,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
          // Labels de secção ("CENTRO DE COMANDO", "OPERAÇÃO") removidos:
          // Cesar validou no smoke que os ícones + rótulos já são suficientes
          // e as labels só ocupavam altura sem valor informativo real.
          _SidebarItem(
            item: AppDestination.management,
            selected: selected == AppDestination.management,
            onTap: () => ref
                .read(navigationProvider.notifier)
                .goTo(AppDestination.management),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final item in destinations)
                  if (item != AppDestination.management)
                    _SidebarItem(
                      item: item,
                      selected: selected == item,
                      onTap: () =>
                          ref.read(navigationProvider.notifier).goTo(item),
                    ),
              ],
            ),
          ),
          Container(height: 1, color: const Color(0xFF203A4D)),
          // Footer compacto: avatar (com tooltip do estado) empilhado em cima
          // dos ícones de acção. O texto "Sessão activa / Demonstração local"
          // saiu do ecrã — leva-se pelo tooltip do avatar.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                // O avatar era decorativo: só tooltip, sem `onTap`. Agora abre o
                // Perfil, que é onde vive o terminar sessão.
                //
                // `Material` + `InkWell` com a mesma forma: a área que recebe o
                // toque é exactamente o círculo desenhado. Era isto que faltava
                // — um `Container` colorido não recebe toque nenhum.
                Tooltip(
                  message: 'Perfil',
                  child: Material(
                    color: const Color(0xFF1D3A4E),
                    shape: const CircleBorder(),
                    child: InkWell(
                      key: chaveDoAvatarDoPerfil,
                      customBorder: const CircleBorder(),
                      onTap: () => mostrarPerfil(context),
                      child: const SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(
                          Icons.person_outline_rounded,
                          size: 18,
                          color: Color(0xFFCEDAE1),
                        ),
                      ),
                    ),
                  ),
                ),
                if (SupabaseConfig.enabled) ...[
                  const SizedBox(height: 8),
                  const _ConvitesButton(onDarkBackground: true),
                ],
              ],
            ),
          ),
        ],
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
              child: Stack(
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
    if (destination == AppDestination.finances) return const FinancasPage();
    if (destination == AppDestination.tasks) return const TarefasPage();
    if (destination == AppDestination.employees) {
      return const CollaboratorsPage();
    }
    if (destination == AppDestination.vehicles) return const VehiclesPage();
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
