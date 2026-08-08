import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format/campos.dart';
import '../../../core/operations/operations_controller.dart';
import '../../../core/documents/at_invoice_qr.dart';
import '../../../core/documents/expense_document_capture.dart';
import '../../../core/documents/expense_document_storage.dart';
import '../../../domain/models/finance.dart';
import '../../../domain/models/operations.dart';

class FinanceListPage extends ConsumerWidget {
  const FinanceListPage({
    super.key,
    required this.title,
    required this.expenses,
  });
  final String title;
  final bool expenses;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(operationsProvider);
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    // Sem isto a lista saía pela ordem de chegada da sincronização — nem
    // data nem nada (achado 20). Mais recente primeiro, como um extracto.
    final list = (expenses ? state.expenses : state.receipts).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final total = expenses
        ? paidExpenseTotal(state.expenses, from, now)
        : receiptTotal(state.receipts, from, now);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Este mês: ${_money(total)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  for (final item in list)
                    Card(
                      child: ListTile(
                        title: Text(_money(item.amountCents)),
                        subtitle: Text(
                          '${item.date.day}/${item.date.month} · ${item.note.isEmpty ? 'Sem nota' : item.note}',
                        ),
                        trailing: item is Expense
                            ? Chip(
                                label: Text(
                                  item.status == ExpensePaymentStatus.paid
                                      ? 'Paga'
                                      : 'Por pagar',
                                ),
                              )
                            : const Chip(label: Text('Recebido')),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RegisterExpensePage extends ConsumerStatefulWidget {
  const RegisterExpensePage({super.key, this.recordedByCollaboratorId});
  final String? recordedByCollaboratorId;
  @override
  ConsumerState<RegisterExpensePage> createState() =>
      _RegisterExpensePageState();
}

class _RegisterExpensePageState extends ConsumerState<RegisterExpensePage> {
  final amount = TextEditingController();
  final note = TextEditingController();
  var category = ExpenseCategory.other;
  late ExpensePaymentStatus status;
  String? documentPath;
  DateTime expenseDate = DateTime.now();
  bool qrDetected = false;
  String? machineId;
  String? vehicleId;

  /// Recusa a mostrar-se junto ao campo, não num `SnackBar`.
  ///
  /// Este ecrã é uma página inteira, não um diálogo — não tem o `aviso` do
  /// [EcraDeFormulario]. Mas o problema é o mesmo que o originou: num
  /// telemóvel deitado com o teclado aberto, o `SnackBar` nasce por baixo do
  /// teclado, escondido. Ficar junto ao campo do valor garante que se vê
  /// mesmo com o teclado ainda aberto — o botão *Guardar*, mais abaixo, pode
  /// não estar.
  String? erro;

  @override
  void initState() {
    super.initState();
    status = widget.recordedByCollaboratorId == null
        ? ExpensePaymentStatus.paid
        : ExpensePaymentStatus.unpaid;
  }

  @override
  Widget build(BuildContext context) {
    final operations = ref.watch(operationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Registar despesa')),
      // SingleChildScrollView: com o teclado aberto num telemóvel deitado,
      // este formulário (valor, documento, duas listas de máquinas/veículos,
      // nota, estado) não cabe todo — sem rolar, transbordava.
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: amount,
                // Com vírgula: `number` seco abre o teclado de inteiros do
                // Android e não há como escrever os cêntimos de um valor.
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Valor (€)'),
              ),
              if (erro != null) _AvisoDeValor(texto: erro!),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final path = await ExpenseDocumentCapture.pickImage();
                      if (path != null) await _useInvoicePhoto(path);
                    },
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Escolher ficheiro'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final path =
                          await ExpenseDocumentCapture.captureFromCamera();
                      if (path != null) await _useInvoicePhoto(path);
                    },
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: const Text('Tirar e ler QR'),
                  ),
                ],
              ),
              if (documentPath != null)
                Text(
                  'Documento associado: $documentPath',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const Text(
                'Sugestões QR/OCR são sempre confirmadas manualmente. Neste dispositivo, se a leitura automática não estiver disponível, preencha os dados abaixo.',
                style: TextStyle(fontSize: 12),
              ),
              DropdownButtonFormField(
                isExpanded: true,
                initialValue: category,
                items: ExpenseCategory.values
                    .map((x) => DropdownMenuItem(value: x, child: Text(x.name)))
                    .toList(),
                onChanged: (v) => setState(() => category = v!),
              ),
              DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: machineId,
                decoration: const InputDecoration(
                  labelText: 'Máquina associada (opcional)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sem máquina associada'),
                  ),
                  ...operations.machines
                      .where((machine) => !machine.archived)
                      .map(
                        (machine) => DropdownMenuItem<String?>(
                          value: machine.id,
                          child: Text(machine.name),
                        ),
                      ),
                ],
                onChanged: (value) => setState(() => machineId = value),
              ),
              DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: vehicleId,
                decoration: const InputDecoration(
                  labelText: 'Veículo associado (opcional)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sem veículo associado'),
                  ),
                  ...operations.vehicles
                      .where((vehicle) => !vehicle.archived)
                      .map(
                        (vehicle) => DropdownMenuItem<String?>(
                          value: vehicle.id,
                          child: Text(vehicle.alias ?? vehicle.plate),
                        ),
                      ),
                ],
                onChanged: (value) => setState(() => vehicleId = value),
              ),
              TextField(
                controller: note,
                decoration: const InputDecoration(
                  labelText: 'Nota / descrição',
                ),
              ),
              if (widget.recordedByCollaboratorId == null)
                DropdownButtonFormField(
                  isExpanded: true,
                  initialValue: status,
                  items: ExpensePaymentStatus.values
                      .map(
                        (x) => DropdownMenuItem(
                          value: x,
                          child: Text(
                            x == ExpensePaymentStatus.paid
                                ? 'Paga'
                                : 'Por pagar',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => status = v!),
                )
              else
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.pending_actions_outlined),
                  title: Text('Enviada para validação da empresa'),
                  subtitle: Text(
                    'Fica por pagar até o gestor confirmar o pagamento ou reembolso.',
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  // `centsDeTexto` devolve `null` tanto para o campo vazio como
                  // para texto ilegível ("1.500.00", letras) — nunca inventa um
                  // zero. Distinguimos os dois só para a mensagem: vazio pede
                  // para preencher, lixo diz o que não se percebeu.
                  final cents = centsDeTexto(amount.text);
                  if (cents == null || cents <= 0) {
                    setState(
                      () => erro = mensagemDeValorInvalido(amount.text),
                    );
                    return;
                  }
                  setState(() => erro = null);
                  final expenseId = 'e${DateTime.now().microsecondsSinceEpoch}';
                  ref
                      .read(operationsProvider.notifier)
                      .saveExpense(
                        Expense(
                          id: expenseId,
                          date: expenseDate,
                          amountCents: cents,
                          category: category,
                          status: status,
                          note: note.text,
                          documentPath: documentPath,
                          machineId: machineId,
                          vehicleId: vehicleId,
                          recordedByCollaboratorId:
                              widget.recordedByCollaboratorId,
                          dataSource: qrDetected
                              ? DocumentDataSource.qr
                              : DocumentDataSource.manual,
                        ),
                      );
                  if (documentPath != null) {
                    try {
                      await ExpenseDocumentStorage.upload(
                        localPath: documentPath!,
                        expenseId: expenseId,
                      );
                    } catch (_) {
                      // context.mounted (não só mounted) — o linter só aceita
                      // esta forma para garantir que o próprio context ainda
                      // pertence à árvore, não só que o State existe.
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'A despesa foi guardada, mas o comprovativo ainda não foi enviado para o arquivo privado.',
                            ),
                          ),
                        );
                      }
                    }
                  }
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _useInvoicePhoto(String path) async {
    final qr = await AtInvoiceQrReader.readFromImage(path);
    if (!mounted) return;
    setState(() {
      documentPath = path;
      qrDetected = qr != null;
      if (qr?.totalCents != null) {
        amount.text = (qr!.totalCents! / 100).toStringAsFixed(2);
      }
      if (qr?.documentDate != null) expenseDate = qr!.documentDate!;
      if (qr?.summary.isNotEmpty ?? false) note.text = qr!.summary;
    });
    if (qr == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fotografia associada. Não foi encontrado um QR de fatura legível; complete os dados manualmente.',
          ),
        ),
      );
    }
  }
}

class RegisterReceiptPage extends ConsumerStatefulWidget {
  const RegisterReceiptPage({
    super.key,
    this.recordedByCollaboratorId,
    this.clienteInicial,
    this.trabalhoInicial,
    this.valorInicialCents,
  });
  final String? recordedByCollaboratorId;

  /// Cliente, trabalho e valor já preenchidos por quem abriu o formulário.
  ///
  /// Existem por causa de **A minha semana**: quando a app já sabe que faltam
  /// 425,50 € do trabalho de terça-feira, obrigar o gestor a escolher o cliente
  /// numa lista, a reserva noutra e a escrever o valor à mão é pedir-lhe que
  /// volte a informar o que ela lhe acabou de dizer. E cada um desses três
  /// passos é uma hipótese de enganar-se — o recebimento ir parar ao trabalho
  /// errado estraga a margem de dois de uma vez.
  final String? clienteInicial, trabalhoInicial;
  final int? valorInicialCents;

  @override
  ConsumerState<RegisterReceiptPage> createState() =>
      _RegisterReceiptPageState();
}

class _RegisterReceiptPageState extends ConsumerState<RegisterReceiptPage> {
  final amount = TextEditingController();
  final note = TextEditingController();
  PaymentMethod method = PaymentMethod.transfer;
  String? customerId;
  String? bookingId;

  @override
  void initState() {
    super.initState();
    customerId = widget.clienteInicial;
    bookingId = widget.trabalhoInicial;
    if (widget.valorInicialCents != null) {
      amount.text = textoDeCents(widget.valorInicialCents);
    }
  }

  /// Ver o comentário simétrico em [_RegisterExpensePageState.erro].
  String? erro;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(operationsProvider);
    final customers = state.customers.where((c) => !c.archived).toList();
    final selectedCustomerId =
        customerId ?? (customers.isEmpty ? null : customers.first.id);
    final customerBookings = state.bookings
        .where((booking) => booking.customerId == selectedCustomerId)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Registar recebimento')),
      // SingleChildScrollView, pela mesma razão da Despesa: com o teclado
      // aberto, o formulário (valor, cliente, reserva, método, nota) não
      // cabia todo.
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: amount,
                // Com vírgula: `number` seco abre o teclado de inteiros do
                // Android e não há como escrever os cêntimos de um valor.
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Valor (€)'),
              ),
              if (erro != null) _AvisoDeValor(texto: erro!),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: selectedCustomerId,
                decoration: const InputDecoration(labelText: 'Cliente'),
                items: customers
                    .map(
                      (customer) => DropdownMenuItem(
                        value: customer.id,
                        child: Text(customer.name),
                      ),
                    )
                    .toList(),
                onChanged: customers.isEmpty
                    ? null
                    : (value) => setState(() {
                        customerId = value;
                        bookingId = null;
                      }),
              ),
              DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: bookingId,
                decoration: const InputDecoration(
                  labelText: 'Associar a reserva (opcional)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sem reserva associada'),
                  ),
                  ...customerBookings.map(
                    (booking) => DropdownMenuItem<String?>(
                      value: booking.id,
                      child: Text(
                        '${booking.startsAt.day}/${booking.startsAt.month} · '
                        // `status.name` punha "rented" e "proposalSent" à
                        // frente do gestor. Visto no Redmi a 4 de Agosto de
                        // 2026, no recebimento aberto a partir de A minha
                        // semana.
                        '${bookingStatusLabel(booking.status)}',
                      ),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => bookingId = value),
              ),
              DropdownButtonFormField(
                isExpanded: true,
                initialValue: method,
                items: PaymentMethod.values
                    .map((x) => DropdownMenuItem(value: x, child: Text(x.name)))
                    .toList(),
                onChanged: (v) => setState(() => method = v!),
              ),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Nota'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: customers.isEmpty
                    ? null
                    : () {
                        final cents = centsDeTexto(amount.text);
                        if (cents == null || cents <= 0) {
                          setState(
                            () => erro = mensagemDeValorInvalido(amount.text),
                          );
                          return;
                        }
                        setState(() => erro = null);
                        ref
                            .read(operationsProvider.notifier)
                            .saveReceipt(
                              Receipt(
                                id: 'r${DateTime.now().microsecondsSinceEpoch}',
                                date: DateTime.now(),
                                amountCents: cents,
                                customerId: selectedCustomerId!,
                                bookingId: bookingId,
                                recordedByCollaboratorId:
                                    widget.recordedByCollaboratorId,
                                method: method,
                                note: note.text,
                              ),
                            );
                        Navigator.pop(context);
                      },
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _money(int cents) =>
    '${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')} €';

/// Recusa a mostrar-se dentro do formulário, junto ao campo do valor — o
/// mesmo desenho visual do `aviso` de [EcraDeFormulario], para quem não
/// vive num diálogo. Ver o comentário em `_RegisterExpensePageState.erro`.
class _AvisoDeValor extends StatelessWidget {
  const _AvisoDeValor({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: tema.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
