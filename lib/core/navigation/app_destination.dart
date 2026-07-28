import 'package:flutter/material.dart';

/// Destinos da barra lateral. A ordem é a ordem em que aparecem.
///
/// Vocabulário fixado na v0.0.5: **Veículos** são os da empresa (carros,
/// carrinhas, com custos) e **Máquinas** são as que se alugam a clientes (com
/// ocupação). Eram tratados como a mesma coisa e não são.
///
/// Rótulos revistos na v0.0.8 (Decisão 2): "Gestão" dizia o que a app faz e não
/// o que o ecrã mostra — passa a **Painel**. "Frota" era jargão de quem já sabe
/// — passa a **Veículos**. "Funcionários" passa a **Colaboradores**, que é a
/// palavra usada em todo o resto da app e no modelo.
enum AppDestination {
  management('Painel', Icons.space_dashboard_outlined),
  machines('Máquinas', Icons.build_outlined),
  bookings('Reservas', Icons.calendar_month_outlined),
  clients('Clientes', Icons.people_outline),
  employees('Colaboradores', Icons.groups_outlined),
  empresa('Empresa', Icons.domain_outlined),
  tasks('Tarefas', Icons.checklist_outlined),

  // ---------------------------------------------------------------------
  // Destinos que deixaram de estar na barra, mas continuam a existir.
  //
  // Migraram para abas dentro de **Empresa**. Ficam no enum porque há código
  // que ainda lhes chama pelo nome — as tarefas com `DestinoTarefa.frota` e
  // `DestinoTarefa.financas`, por exemplo — e porque manter o nome permite que
  // um salto para eles continue a funcionar, abrindo a aba certa em vez de
  // rebentar. Apagá-los agora obrigava a mudar tudo isso na mesma sprint.
  // ---------------------------------------------------------------------
  finances('Finanças', Icons.credit_card_outlined),
  vehicles('Veículos', Icons.local_shipping_outlined);

  const AppDestination(this.label, this.icon);
  final String label;
  final IconData icon;

  /// A aba de Empresa que este destino passou a ser, se passou a ser alguma.
  ///
  /// É o que mantém os saltos antigos a funcionar: quem navegasse para
  /// "Finanças" continua a ir parar às finanças, agora dentro de Empresa.
  AbaDaEmpresa? get abaDeEmpresa => switch (this) {
    AppDestination.finances => AbaDaEmpresa.financas,
    AppDestination.vehicles => AbaDaEmpresa.veiculos,
    _ => null,
  };
}

/// As abas do destino Empresa, pela ordem em que aparecem.
enum AbaDaEmpresa {
  dados('Dados', Icons.badge_outlined),
  regime('Regime', Icons.account_balance_outlined),
  custosFixos('Custos fixos', Icons.receipt_long_outlined),
  veiculos('Veículos', Icons.local_shipping_outlined),
  financas('Finanças', Icons.credit_card_outlined),
  estado('Estado', Icons.event_note_outlined);

  const AbaDaEmpresa(this.label, this.icon);
  final String label;
  final IconData icon;
}
