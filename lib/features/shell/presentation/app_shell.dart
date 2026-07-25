import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/layout/phone_orientation_lock.dart';
import '../../../core/navigation/app_destination.dart';
import '../../../core/navigation/navigation_controller.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../core/session/demo_session.dart';
import '../../../core/theme/punho_theme.dart';
import '../../../shared/widgets/brand_lockup.dart';
import '../../collaborator/presentation/collaborator_shell.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../licenca/presentation/licenca_banner.dart';
import '../../operations/presentation/operational_pages.dart';
import '../../workforce/presentation/workforce_pages.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operational = ref.watch(operationsProvider);
    final session = ref.watch(demoSessionProvider);
    if (!operational.onboarded) return const OnboardingPage();
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

    if (isDesktop) {
      return PhoneOrientationLock(
        orientation: PhoneOrientation.landscape,
        lockOnTablets: true,
        child: Scaffold(
          body: Row(
            children: [
              _Sidebar(destinations: destinations, selected: destination),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    return PhoneOrientationLock(
      orientation: PhoneOrientation.landscape,
      lockOnTablets: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Punho'),
          actions: [
            if (!SupabaseConfig.enabled) const _ProfileSelector(),
            if (SupabaseConfig.enabled) const _SignOutButton(),
          ],
        ),
        drawer: Drawer(
          child: _MobileMenu(destinations: destinations, selected: destination),
        ),
        body: content,
      ),
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

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({this.onDarkBackground = false});
  final bool onDarkBackground;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Terminar sessão',
    color: onDarkBackground ? const Color(0xFFB7C5CE) : null,
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
    width: 272,
    color: PunhoTheme.navyDeep,
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 28, 20, 28),
            child: BrandLockup(),
          ),
          const _SidebarSectionLabel('CENTRO DE COMANDO'),
          _SidebarItem(
            item: AppDestination.management,
            selected: selected == AppDestination.management,
            onTap: () => ref
                .read(navigationProvider.notifier)
                .goTo(AppDestination.management),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 22),
            child: _SidebarSectionLabel('OPERAÇÃO'),
          ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1D3A4E),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    size: 18,
                    color: Color(0xFFCEDAE1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    SupabaseConfig.enabled
                        ? 'Sessão activa'
                        : 'Demonstração local',
                    style: const TextStyle(
                      color: Color(0xFFCEDAE1),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (SupabaseConfig.enabled)
                  const _SignOutButton(onDarkBackground: true),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _SidebarSectionLabel extends StatelessWidget {
  const _SidebarSectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF7E96A6),
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    ),
  );
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppDestination item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1B3A4D) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? const Border(
                    left: BorderSide(color: PunhoTheme.orange, width: 3),
                  )
                : null,
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(
                item.icon,
                size: 21,
                color: selected ? PunhoTheme.orange : const Color(0xFFB7C7D1),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFFB7C7D1),
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected)
                const Padding(
                  padding: EdgeInsets.only(right: 14),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: PunhoTheme.orange,
                  ),
                ),
            ],
          ),
        ),
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
