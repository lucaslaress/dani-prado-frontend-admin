import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/http/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../customers/customer_model.dart';
import '../customers/customers_service.dart';
import '../products/products_service.dart';
import 'pdv_cart_provider.dart';
import 'sale_model.dart';
import 'sales_service.dart';

final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vendas'),
          bottom: const TabBar(
            labelColor: AppColors.white,
            unselectedLabelColor: AppColors.grey500,
            indicatorColor: AppColors.white,
            tabs: [
              Tab(text: 'Nova Venda'),
              Tab(text: 'Histórico'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PdvTab(),
            _HistoryTab(),
          ],
        ),
      ),
    );
  }
}

class _PdvTab extends StatelessWidget {
  const _PdvTab();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 6, child: _CartPanel()),
        VerticalDivider(width: 1),
        Expanded(flex: 4, child: _CheckoutPanel()),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────
// PAINEL ESQUERDO — Busca + Carrinho
// ─────────────────────────────────────────────────────

class _CartPanel extends StatefulWidget {
  const _CartPanel();

  @override
  State<_CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends State<_CartPanel> {
  final _codeController = TextEditingController();
  String? _searchError;
  bool _isSearching = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _searchByCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _searchError = 'O código deve ter 6 dígitos');
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final service = ProductsService(context.read<ApiClient>());
      final product = await service.getProductByVariantCode(code);
      final variant = product.variants.firstWhere((v) => v.code == code);

      if (!mounted) return;
      context.read<PdvCartProvider>().addItem(CartItem(
            variantCode: variant.code,
            productName: product.name,
            color: variant.color,
            size: variant.size,
            unitPriceInCents: (product.effectivePrice * 100).round(),
          ));

      _codeController.clear();
    } catch (e) {
      setState(() => _searchError = e.toString());
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<PdvCartProvider>();

    return Column(
      children: [
        // Campo de busca por código
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Código da variação (6 dígitos)',
                    prefixIcon: const Icon(Icons.qr_code),
                    errorText: _searchError,
                  ),
                  onSubmitted: (_) => _searchByCode(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _isSearching ? null : _searchByCode,
                icon: _isSearching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.white),
                      )
                    : const Icon(Icons.add),
                label: const Text('Adicionar'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.black,
                  minimumSize: const Size(0, 52),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Lista de itens do carrinho
        Expanded(
          child: cart.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhum item no carrinho.\nDigite o código da variação acima.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.grey700),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _CartItemRow(item: cart.items[i]),
                ),
        ),
        const Divider(height: 1),

        // Totais
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _TotalRow(
                  label: 'Subtotal',
                  value: _currency.format(cart.subtotalInCents / 100)),
              if (cart.discountInCents > 0)
                _TotalRow(
                  label: 'Desconto',
                  value: '- ${_currency.format(cart.discountInCents / 100)}',
                  color: AppColors.success,
                ),
              if (cart.appliedCreditInCents > 0)
                _TotalRow(
                  label: 'Crédito',
                  value: '- ${_currency.format(cart.appliedCreditInCents / 100)}',
                  color: AppColors.success,
                ),
              const Divider(),
              _TotalRow(
                label: 'Total',
                value: _currency.format(cart.totalInCents / 100),
                bold: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final CartItem item;
  const _CartItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<PdvCartProvider>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.productName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${item.color} • ${item.size}',
                      style: const TextStyle(
                          color: AppColors.grey700, fontSize: 13)),
                ],
              ),
            ),
            // Controle de quantidade
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 18),
                  onPressed: () => cart.updateQuantity(
                      item.variantCode, item.quantity - 1),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${item.quantity}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: () => cart.updateQuantity(
                      item.variantCode, item.quantity + 1),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Text(_currency.format(item.total),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: AppColors.grey500),
              onPressed: () => cart.removeItem(item.variantCode),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _TotalRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 16 : 14,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// PAINEL DIREITO — Cliente + Pagamento + Finalizar
// ─────────────────────────────────────────────────────

class _CheckoutPanel extends StatefulWidget {
  const _CheckoutPanel();

  @override
  State<_CheckoutPanel> createState() => _CheckoutPanelState();
}

class _CheckoutPanelState extends State<_CheckoutPanel> {
  final _discountController = TextEditingController();
  final _paymentAmountController = TextEditingController();
  PaymentMethod _selectedMethod = PaymentMethod.pix;
  bool _discountIsPercent = true;
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void dispose() {
    _discountController.dispose();
    _paymentAmountController.dispose();
    super.dispose();
  }

  IconData _paymentIcon(PaymentMethod method) => switch (method) {
        PaymentMethod.cash => Icons.payments_outlined,
        PaymentMethod.pix => Icons.pix,
        PaymentMethod.creditCard => Icons.credit_card_outlined,
        PaymentMethod.debitCard => Icons.credit_card,
        PaymentMethod.other => Icons.more_horiz,
      };

  void _applyDiscount() {
    final cart = context.read<PdvCartProvider>();
    final raw = _discountController.text.trim().replaceAll(',', '.');
    final value = double.tryParse(raw);
    if (value == null || value <= 0) return;

    int cents;
    if (_discountIsPercent) {
      final pct = value.clamp(0.0, 100.0);
      cents = (cart.subtotalInCents * pct / 100).round();
    } else {
      cents = (value * 100).round();
    }
    cart.setDiscount(cents);
    _discountController.clear();
  }

  void _addPayment() {
    final cart = context.read<PdvCartProvider>();
    final raw = _paymentAmountController.text.replaceAll(',', '.');
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) return;

    cart.addPaymentMethod(PaymentEntry(
      method: _selectedMethod,
      amountInCents: (amount * 100).round(),
    ));
    _paymentAmountController.clear();
  }

  Future<void> _finalizeSale() async {
    final cart = context.read<PdvCartProvider>();
    if (cart.isEmpty) {
      setState(() => _submitError = 'Adicione ao menos um produto');
      return;
    }
    if (cart.paymentMethods.isEmpty && cart.totalInCents > 0) {
      setState(() => _submitError = 'Adicione ao menos uma forma de pagamento');
      return;
    }
    if (!cart.isFullyPaid) {
      setState(() => _submitError =
          'Falta pagar ${_currency.format(cart.remainingInCents / 100)}');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final service = SalesService(context.read<ApiClient>());
      await service.createSale(
        items: cart.items,
        paymentMethods: cart.paymentMethods,
        customerId: cart.selectedCustomer?.id,
        walkInCustomer: cart.walkInCustomer,
        manualDiscountInCents: cart.discountInCents,
      );

      if (!mounted) return;
      cart.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Venda registrada com sucesso!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      setState(() => _submitError = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickCustomer() async {
    final cart = context.read<PdvCartProvider>();
    final selected = await showDialog<CustomerModel>(
      context: context,
      builder: (_) => _CustomerPickerDialog(
        service: CustomersService(context.read<ApiClient>()),
      ),
    );
    if (selected != null) cart.setCustomer(selected);
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<PdvCartProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cliente ──
          _SectionTitle('Cliente'),
          const SizedBox(height: 8),
          if (cart.selectedCustomer != null) ...[
            _SelectedChip(
              label: cart.selectedCustomer!.name,
              onRemove: cart.clearCustomer,
            ),
            if (cart.selectedCustomer!.creditInCents > 0) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined,
                        size: 16, color: AppColors.success),
                    const SizedBox(width: 8),
                    Text(
                      'Crédito disponível: ${_currency.format(cart.selectedCustomer!.credit)}',
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ] else
            OutlinedButton.icon(
              onPressed: _pickCustomer,
              icon: const Icon(Icons.person_search),
              label: const Text('Buscar cliente cadastrado'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          const SizedBox(height: 24),

          // ── Desconto ──
          _SectionTitle('Desconto (opcional)'),
          const SizedBox(height: 8),
          if (cart.discountInCents > 0)
            _SelectedChip(
              label: '${_currency.format(cart.discountInCents / 100)} de desconto',
              onRemove: cart.clearDiscount,
            )
          else
            Row(
              children: [
                // Toggle % / R$
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('%')),
                    ButtonSegment(value: false, label: Text('R\$')),
                  ],
                  selected: {_discountIsPercent},
                  onSelectionChanged: (v) {
                    _discountController.clear();
                    setState(() => _discountIsPercent = v.first);
                  },
                  style: const ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _discountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: _discountIsPercent
                        ? []
                        : [_CurrencyInputFormatter()],
                    decoration: InputDecoration(
                      hintText: _discountIsPercent ? '0' : '0,00',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _applyDiscount,
                  child: const Text('Aplicar'),
                ),
              ],
            ),
          const SizedBox(height: 24),

          // ── Formas de pagamento ──
          _SectionTitle('Pagamento'),
          const SizedBox(height: 8),
          ...cart.paymentMethods.asMap().entries.map(
                (e) => _PaymentChip(
                  entry: e.value,
                  onRemove: () => cart.removePaymentMethod(e.key),
                ),
              ),
          const SizedBox(height: 8),
          // Chips de método de pagamento
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PaymentMethod.values.map((m) {
              final selected = m == _selectedMethod;
              return GestureDetector(
                onTap: () => setState(() => _selectedMethod = m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.black : AppColors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? AppColors.black : AppColors.grey300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _paymentIcon(m),
                        size: 15,
                        color: selected ? AppColors.white : AppColors.grey700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        m.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: selected ? AppColors.white : AppColors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          // Campo de valor + botão adicionar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _paymentAmountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_CurrencyInputFormatter()],
                  decoration: const InputDecoration(
                    hintText: '0,00',
                    prefixText: r'R$ ',
                  ),
                  onSubmitted: (_) => _addPayment(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _addPayment,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Adicionar'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.black,
                  minimumSize: const Size(0, 52),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Falta pagar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cart.isFullyPaid
                  ? AppColors.success.withAlpha(20)
                  : AppColors.grey100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: cart.isFullyPaid ? AppColors.success : AppColors.grey300,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  cart.isFullyPaid ? 'Pagamento completo' : 'Falta pagar',
                  style: TextStyle(
                    color: cart.isFullyPaid
                        ? AppColors.success
                        : AppColors.grey900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!cart.isFullyPaid)
                  Text(
                    _currency.format(cart.remainingInCents / 100),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (_submitError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_submitError!,
                  style: const TextStyle(color: AppColors.error)),
            ),

          // Botão finalizar
          ElevatedButton(
            onPressed: (cart.isEmpty || _isSubmitting) ? null : _finalizeSale,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.white),
                  )
                : const Text('Finalizar Venda'),
          ),
        ],
      ),
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppColors.grey700,
            letterSpacing: 0.5));
  }
}

class _SelectedChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _SelectedChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.grey300),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  final PaymentEntry entry;
  final VoidCallback onRemove;
  const _PaymentChip({required this.entry, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: _SelectedChip(
        label: '${entry.method.label} — ${_currency.format(entry.amount)}',
        onRemove: onRemove,
      ),
    );
  }
}

// ─── Diálogo de busca de cliente ─────────────────────

class _CustomerPickerDialog extends StatefulWidget {
  final CustomersService service;
  const _CustomerPickerDialog({required this.service});

  @override
  State<_CustomerPickerDialog> createState() => _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends State<_CustomerPickerDialog> {
  final _searchController = TextEditingController();
  List<CustomerModel> _allCustomers = [];
  bool _isLoading = true;

  List<CustomerModel> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _allCustomers;
    final digits = q.replaceAll(RegExp(r'\D'), '');
    return _allCustomers.where((c) {
      if (c.name.toLowerCase().contains(q)) return true;
      if (digits.isNotEmpty && c.cpf.contains(digits)) return true;
      if (digits.isNotEmpty && c.phone.contains(digits)) return true;
      return false;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await widget.service.listCustomers();
      if (mounted) setState(() => _allCustomers = results);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Dialog(
      child: SizedBox(
        width: 500,
        height: 500,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Buscar por nome ou CPF...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final c = list[i];
                        return ListTile(
                          title: Text(c.name),
                          subtitle: Text(c.formattedCpf),
                          onTap: () => Navigator.of(context).pop(c),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// ABA HISTORICO DE VENDAS
// ─────────────────────────────────────────────────────

class _HistoryTab extends StatefulWidget {
  const _HistoryTab();

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  late final SalesService _service;
  List<SaleModel> _sales = [];
  bool _isLoading = false;
  String? _error;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  static final _dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
  static final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');

  @override
  void initState() {
    super.initState();
    _service = SalesService(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final end = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
      final sales = await _service.listSales(startDate: _startDate, endDate: end);
      setState(() => _sales = sales);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate({required bool isEnd}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isEnd ? _endDate : _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (picked == null) return;
    setState(() {
      if (isEnd) {
        _endDate = picked;
        if (_endDate.isBefore(_startDate)) _startDate = _endDate;
      } else {
        _startDate = picked;
        if (_startDate.isAfter(_endDate)) _endDate = _startDate;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterBar(),
        const Divider(height: 1),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          const Text('De:', style: TextStyle(color: AppColors.grey700, fontSize: 13)),
          const SizedBox(width: 8),
          _DateChip(label: _dateFormat.format(_startDate), onTap: () => _pickDate(isEnd: false)),
          const SizedBox(width: 16),
          const Text('Ate:', style: TextStyle(color: AppColors.grey700, fontSize: 13)),
          const SizedBox(width: 8),
          _DateChip(label: _dateFormat.format(_endDate), onTap: () => _pickDate(isEnd: true)),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: _isLoading ? null : _load,
            icon: _isLoading
                ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                : const Icon(Icons.search, size: 18),
            label: const Text('Buscar'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.black, foregroundColor: AppColors.white),
          ),
          const Spacer(),
          if (!_isLoading && _error == null)
            Text('${_sales.length} venda${_sales.length != 1 ? "s" : ""}',
                style: const TextStyle(color: AppColors.grey700, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Tentar novamente')),
          ],
        ),
      );
    }
    if (_sales.isEmpty) {
      return const Center(
        child: Text('Nenhuma venda encontrada neste periodo.',
            style: TextStyle(color: AppColors.grey700)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _sales.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _SaleHistoryCard(
        sale: _sales[i],
        currency: _currency,
        dateTimeFormat: _dateTimeFormat,
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DateChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.grey100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.grey300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 14, color: AppColors.grey700),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.grey900)),
          ],
        ),
      ),
    );
  }
}

class _SaleHistoryCard extends StatelessWidget {
  final SaleModel sale;
  final NumberFormat currency;
  final DateFormat dateTimeFormat;
  const _SaleHistoryCard({required this.sale, required this.currency, required this.dateTimeFormat});

  Color get _statusColor => switch (sale.status) {
        'completed' => AppColors.success,
        'partially_returned' => const Color(0xFFF57C00),
        'fully_returned' => AppColors.error,
        _ => AppColors.grey500,
      };

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(sale.createdAt)?.toLocal();
    final paymentSummary = sale.paymentMethods
        .map((p) => '${p.method.label} ${currency.format(p.amount)}')
        .join(' + ');

    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 10, height: 10,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(shape: BoxShape.circle, color: _statusColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sale.displayCustomer,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(sale.sellerName,
                      style: const TextStyle(color: AppColors.grey700, fontSize: 12)),
                  Row(
                    children: [
                      Text('#${sale.id.substring(0, 8).toUpperCase()}',
                          style: const TextStyle(color: AppColors.grey500, fontSize: 11)),
                      const SizedBox(width: 2),
                      InkWell(
                        onTap: () => Clipboard.setData(ClipboardData(text: sale.id)),
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(Icons.copy, size: 11, color: AppColors.grey500),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(currency.format(sale.total),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(sale.statusLabel, style: TextStyle(color: _statusColor, fontSize: 11)),
              ],
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            children: [
              Text(
                date != null ? dateTimeFormat.format(date) : sale.createdAt,
                style: const TextStyle(color: AppColors.grey500, fontSize: 11),
              ),
              if (sale.manualDiscountInCents > 0) ...[
                const Text('  ·  ', style: TextStyle(color: AppColors.grey500, fontSize: 11)),
                Text(
                  'Desconto: ${currency.format(sale.manualDiscountInCents / 100)}',
                  style: const TextStyle(color: AppColors.success, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                ...sale.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.productName}  ${item.variantColor} · ${item.variantSize}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Text(
                            'x${item.quantity}  ${currency.format(item.totalInCents / 100)}',
                            style: const TextStyle(fontSize: 13, color: AppColors.grey700),
                          ),
                        ],
                      ),
                    )),
                if (sale.manualDiscountInCents > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Desconto', style: TextStyle(color: AppColors.success, fontSize: 13)),
                      Text('- ${currency.format(sale.discount)}',
                          style: const TextStyle(color: AppColors.success, fontSize: 13)),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                if (paymentSummary.isNotEmpty)
                  Text('Pagamento: $paymentSummary',
                      style: const TextStyle(fontSize: 12, color: AppColors.grey700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      return newValue.copyWith(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
    final cents = int.parse(digits);
    final intPart = cents ~/ 100;
    final decPart = cents % 100;
    final formatted = '$intPart,${decPart.toString().padLeft(2, '0')}';
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
