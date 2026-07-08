import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/http/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../sales/sale_model.dart';
import '../sales/sales_service.dart';
import 'return_model.dart';
import 'returns_service.dart';

Future<ReturnModel?> showReturnForm(BuildContext context) {
  final api = context.read<ApiClient>();
  return showDialog<ReturnModel>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ReturnForm(
      salesService: SalesService(api),
      returnsService: ReturnsService(api),
    ),
  );
}

class ReturnForm extends StatefulWidget {
  final SalesService salesService;
  final ReturnsService returnsService;

  const ReturnForm({
    super.key,
    required this.salesService,
    required this.returnsService,
  });

  @override
  State<ReturnForm> createState() => _ReturnFormState();
}

class _ReturnFormState extends State<ReturnForm> {
  final _saleIdController = TextEditingController();
  final _reasonController = TextEditingController();

  SaleModel? _sale;
  bool _isSearching = false;
  String? _searchError;

  // variantCode → quantidade selecionada para devolver (0 = não devolver)
  final Map<String, int> _selectedQty = {};
  String _returnType = 'standard';

  bool _isSubmitting = false;
  String? _submitError;

  static final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');

  @override
  void dispose() {
    _saleIdController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _searchSale() async {
    final id = _saleIdController.text.trim();
    if (id.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchError = null;
      _sale = null;
      _selectedQty.clear();
    });

    try {
      final sale = await widget.salesService.getSale(id);
      setState(() {
        _sale = sale;
        // Inicializa todos os itens com quantidade 0
        for (final item in sale.items) {
          _selectedQty[item.variantCode] = 0;
        }
      });
    } catch (e) {
      setState(() => _searchError = 'Venda não encontrada. Verifique o ID.');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  bool get _hasSelection =>
      _selectedQty.values.any((qty) => qty > 0);

  Future<void> _submit() async {
    if (_sale == null) return;
    if (!_hasSelection) {
      setState(() => _submitError = 'Selecione ao menos um item para devolver');
      return;
    }
    final reason = _reasonController.text.trim();
    if (reason.length < 3) {
      setState(() => _submitError = 'Informe o motivo da devolução');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final items = _selectedQty.entries
          .where((e) => e.value > 0)
          .map((e) => {'variantCode': e.key, 'quantity': e.value})
          .toList();

      final ret = await widget.returnsService.createReturn(
        saleId: _sale!.id,
        items: items,
        reason: reason,
        type: _returnType,
      );
      if (mounted) Navigator.of(context).pop(ret);
    } catch (e) {
      setState(() => _submitError = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 580,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 640),
          child: Column(
            children: [
              _buildHeader(context),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTypeSelector(),
                      const SizedBox(height: 20),
                      _buildSearchSection(),
                      if (_sale != null) ...[
                        const SizedBox(height: 24),
                        _buildSaleInfo(),
                        const SizedBox(height: 16),
                        _buildItemsSection(),
                        const SizedBox(height: 20),
                        _buildReasonField(),
                      ],
                      if (_submitError != null) ...[
                        const SizedBox(height: 12),
                        Text(_submitError!,
                            style:
                                const TextStyle(color: AppColors.error)),
                      ],
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 24, 16),
      child: Row(
        children: [
          Text(
            'Nova devolução',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _onTypeChanged(String type) {
    setState(() {
      _returnType = type;
      if (type == 'correction' && _sale != null) {
        for (final item in _sale!.items) {
          _selectedQty[item.variantCode] = item.quantity;
        }
      }
    });
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tipo de devolução',
          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.grey700),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'standard',
              label: Text('Padrão'),
              icon: Icon(Icons.swap_horiz),
            ),
            ButtonSegment(
              value: 'correction',
              label: Text('Correção'),
              icon: Icon(Icons.edit_off),
            ),
          ],
          selected: {_returnType},
          onSelectionChanged: (s) => _onTypeChanged(s.first),
          style: ButtonStyle(
            iconSize: WidgetStateProperty.all(16),
          ),
        ),
        if (_returnType == 'correction') ...[
          const SizedBox(height: 8),
          const Text(
            'Todos os itens serão selecionados. Não gera crédito para o cliente.',
            style: TextStyle(color: AppColors.grey700, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildSearchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ID da venda',
          style:
              TextStyle(fontWeight: FontWeight.w600, color: AppColors.grey700),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _saleIdController,
                decoration: InputDecoration(
                  hintText: 'Cole o ID da venda aqui',
                  errorText: _searchError,
                ),
                onSubmitted: (_) => _searchSale(),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _isSearching ? null : _searchSale,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.black,
                foregroundColor: AppColors.white,
              ),
              child: _isSearching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.white),
                    )
                  : const Text('Buscar'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSaleInfo() {
    final sale = _sale!;
    final date = DateTime.tryParse(sale.createdAt);
    final dateStr = date != null
        ? DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(date)
        : sale.createdAt;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.grey300),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vendedor: ${sale.sellerName}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (sale.customerName != null)
                  Text('Cliente: ${sale.customerName}',
                      style: const TextStyle(
                          color: AppColors.grey700, fontSize: 13)),
                Text(dateStr,
                    style: const TextStyle(
                        color: AppColors.grey500, fontSize: 12)),
              ],
            ),
          ),
          Text(
            _currency.format(sale.total),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    final sale = _sale!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Itens para devolver',
          style:
              TextStyle(fontWeight: FontWeight.w600, color: AppColors.grey700),
        ),
        const SizedBox(height: 8),
        ...sale.items.map((item) => _ItemRow(
              item: item,
              selectedQty: _selectedQty[item.variantCode] ?? 0,
              onChanged: (qty) => setState(
                  () => _selectedQty[item.variantCode] = qty),
              currency: _currency,
              locked: _returnType == 'correction',
            )),
      ],
    );
  }

  Widget _buildReasonField() {
    return TextField(
      controller: _reasonController,
      maxLines: 2,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Motivo da devolução',
        alignLabelWithHint: true,
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed:
                _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: (_sale == null || _isSubmitting) ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.white),
                  )
                : const Text('Registrar devolução'),
          ),
        ],
      ),
    );
  }
}

// Linha de um item com controle de quantidade
class _ItemRow extends StatelessWidget {
  final SaleItemModel item;
  final int selectedQty;
  final ValueChanged<int> onChanged;
  final NumberFormat currency;
  final bool locked;

  const _ItemRow({
    required this.item,
    required this.selectedQty,
    required this.onChanged,
    required this.currency,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Checkbox(
            value: locked ? true : selectedQty > 0,
            onChanged: locked ? null : (v) => onChanged(v == true ? 1 : 0),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${item.variantCode} · ${item.variantColor} · ${item.variantSize} · ${currency.format(item.unitPrice)} un.',
                  style: const TextStyle(
                      color: AppColors.grey700, fontSize: 12),
                ),
              ],
            ),
          ),
          if (locked) ...[
            SizedBox(
              width: 32,
              child: Text(
                '${item.quantity}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
          ] else if (selectedQty > 0) ...[
            IconButton(
              icon: const Icon(Icons.remove, size: 18),
              onPressed: selectedQty > 1
                  ? () => onChanged(selectedQty - 1)
                  : () => onChanged(0),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            SizedBox(
              width: 32,
              child: Text(
                '$selectedQty',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 18),
              onPressed: selectedQty < item.quantity
                  ? () => onChanged(selectedQty + 1)
                  : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ] else ...[
            Text(
              'máx. ${item.quantity}',
              style: const TextStyle(
                  color: AppColors.grey500, fontSize: 12),
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}
