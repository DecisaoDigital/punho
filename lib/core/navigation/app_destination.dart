import 'package:flutter/material.dart';

/// Destinos da barra lateral. A ordem é a ordem em que aparecem.
///
/// Vocabulário fixado na v0.0.5: **Frota** são os veículos da empresa (carros,
/// carrinhas, com custos) e **Máquinas** são as que se alugam a clientes (com
/// ocupação). Eram tratados como a mesma coisa e não são.
enum AppDestination {
  management('Gestão', Icons.space_dashboard_outlined),
  machines('Máquinas', Icons.build_outlined),
  clients('Clientes', Icons.people_outline),
  bookings('Reservas', Icons.calendar_month_outlined),
  finances('Finanças', Icons.credit_card_outlined),
  employees('Funcionários', Icons.groups_outlined),
  vehicles('Frota', Icons.local_shipping_outlined),
  tasks('Tarefas', Icons.checklist_outlined);

  const AppDestination(this.label, this.icon);
  final String label;
  final IconData icon;
}
