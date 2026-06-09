import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/http/api_client.dart';
import '../../core/theme/app_theme.dart';
import 'reports_service.dart';

final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final ReportsService _service;

  DateTime _startDate =
      DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  Map<String, dynamic>? _summary;
  List<dynamic> _topProducts = [];
  List<dynamic> _lowStock = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = ReportsService(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getSalesSummary(_startDate, _endDate),
        _service.getTopProducts(_startDate, _endDate),
        _service.getLowStock(),
      ]);
      setState(() {
        _summary = results[0] as Map<String, dynamic>;
        _topProducts = results[1] as List;
        _lowStock = results[2] as List;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      locale: const Locale('pt', 'BR'),
    );
    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios'),
        actions: [
          TextButton.icon(
            onPressed: _pickDateRange,
            icon: const Icon(Icons.date_range, color: AppColors.white),
            label: Text(
              '${_startDate.day}/${_startDate.month} – ${_endDate.day}/${_endDate.month}',
              style: const TextStyle(color: AppColors.white),
            ),
          ),
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _load),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!,
                      style: const TextStyle(color: AppColors.error)),
                  const SizedBox(height: 12),
                  OutlinedButton(
                      onPressed: _load,
                      child: const Text('Tentar novamente')),
                ]))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_summary != null) ...[
                        _SectionTitle('Resumo do período'),
                        const SizedBox(height: 12),
                        _SummaryCards(summary: _summary!),
                        const SizedBox(height: 32),
                      ],
                      if (_topProducts.isNotEmpty) ...[
                        _SectionTitle('Produtos mais vendidos'),
                        const SizedBox(height: 12),
                        _TopProductsList(products: _topProducts),
                        const SizedBox(height: 32),
                      ],
                      if (_lowStock.isNotEmpty) ...[
                        _SectionTitle('Estoque baixo'),
                        const SizedBox(height: 12),
                        _LowStockList(items: _lowStock),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.black));
  }
}

class _SummaryCards extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _SummaryCards({required this.summary});

  @override
  Widget build(BuildContext context) {
    final totalSales = summary['totalSales'] as int? ?? 0;
    final revenue = (summary['totalRevenueInCents'] as int? ?? 0) / 100;
    final discount = (summary['totalDiscountInCents'] as int? ?? 0) / 100;
    final netRevenue = (summary['netRevenueInCents'] as int? ?? 0) / 100;

    return Row(
      children: [
        _StatCard(label: 'Total de vendas', value: '$totalSales'),
        const SizedBox(width: 12),
        _StatCard(label: 'Receita bruta', value: _currency.format(revenue)),
        const SizedBox(width: 12),
        _StatCard(label: 'Descontos', value: _currency.format(discount)),
        const SizedBox(width: 12),
        _StatCard(
            label: 'Receita líquida',
            value: _currency.format(netRevenue),
            highlight: true),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _StatCard(
      {required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        color: highlight ? AppColors.black : AppColors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: highlight ? AppColors.grey500 : AppColors.grey700)),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: highlight ? AppColors.white : AppColors.black)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopProductsList extends StatelessWidget {
  final List<dynamic> products;
  const _TopProductsList({required this.products});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: products.take(10).map((p) {
        final product = p as Map<String, dynamic>;
        return Card(
          child: ListTile(
            title: Text(product['productName'] as String? ?? ''),
            subtitle: Text(
                '${product['variantColor']} • ${product['variantSize']} • Cód. ${product['variantCode']}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${product['totalQuantitySold']} un.',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                    _currency.format(
                        (product['totalRevenueInCents'] as int) / 100),
                    style: const TextStyle(
                        color: AppColors.grey700, fontSize: 12)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LowStockList extends StatelessWidget {
  final List<dynamic> items;
  const _LowStockList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((i) {
        final item = i as Map<String, dynamic>;
        return Card(
          child: ListTile(
            leading:
                const Icon(Icons.warning_amber, color: AppColors.error),
            title: Text(item['productName'] as String? ?? ''),
            subtitle: Text(
                '${item['variantColor']} • ${item['variantSize']} • Cód. ${item['variantCode']}'),
            trailing: Text(
              '${item['currentStock']} un.',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.error),
            ),
          ),
        );
      }).toList(),
    );
  }
}
