import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/http/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../sales/sales_service.dart';
import 'return_form.dart';
import 'return_model.dart';
import 'returns_service.dart';

final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
final _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  late final ReturnsService _returnsService;
  late final SalesService _salesService;

  List<ReturnModel> _returns = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiClient>();
    _returnsService = ReturnsService(api);
    _salesService = SalesService(api);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Busca todas as vendas com devolução (parcial ou total)
      final sales = await _salesService.listSales();
      final returnedSales = sales.where((s) =>
          s.status == 'partially_returned' || s.status == 'fully_returned');

      // Busca devoluções de cada venda em paralelo
      final nestedLists = await Future.wait(
        returnedSales.map((s) => _returnsService.listReturnsBySale(s.id)),
      );

      final allReturns = nestedLists.expand((list) => list).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() => _returns = allReturns);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devoluções'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          FilledButton.icon(
            onPressed: () async {
              final created = await showReturnForm(context);
              if (created != null) {
                setState(() => _returns.insert(0, created));
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Nova devolução'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.black,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 12),
                      OutlinedButton(
                          onPressed: _load,
                          child: const Text('Tentar novamente')),
                    ],
                  ),
                )
              : _returns.isEmpty
                  ? const Center(
                      child: Text('Nenhuma devolução registrada.',
                          style: TextStyle(color: AppColors.grey700)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: _returns.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _ReturnCard(ret: _returns[i]),
                    ),
    );
  }
}

class _ReturnCard extends StatelessWidget {
  final ReturnModel ret;
  const _ReturnCard({required this.ret});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(ret.createdAt)?.toLocal();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Venda #${ret.saleId.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('Por: ${ret.processedByName}',
                        style: const TextStyle(
                            color: AppColors.grey700, fontSize: 13)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_currency.format(ret.totalRefunded),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                            fontSize: 15)),
                    if (date != null)
                      Text(_dateFormat.format(date),
                          style: const TextStyle(
                              color: AppColors.grey500, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Motivo: ${ret.reason}',
                    style: const TextStyle(color: AppColors.grey700, fontSize: 13)),
                const SizedBox(width: 8),
                if (ret.isCorrection)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.grey100,
                      border: Border.all(color: AppColors.grey300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Correção',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.grey700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...ret.items.map((item) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '• ${item.productName} (${item.variantCode}) × ${item.quantity}',
                    style:
                        const TextStyle(color: AppColors.grey700, fontSize: 13),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
