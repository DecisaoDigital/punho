import 'package:flutter/material.dart';

enum AppDestination {
  management('Gestão', Icons.space_dashboard_outlined),
  employees('Funcionários', Icons.groups_outlined),
  machines('Máquinas', Icons.precision_manufacturing_outlined),
  clients('Clientes', Icons.people_outline),
  bookings('Marcações / Reservas', Icons.calendar_month_outlined),
  vehicles('Veículos', Icons.local_shipping_outlined);

  const AppDestination(this.label, this.icon);
  final String label;
  final IconData icon;
}
