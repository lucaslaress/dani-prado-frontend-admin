import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/http/api_client.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../reports/reports_service.dart';
import '../sales/sale_model.dart';
import '../sales/sales_service.dart';

final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
final _dateFormat = DateFormat("EEEE, d 'de' MMMM", 'pt_BR');

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final ReportsService _service;
  late final SalesService _salesService;

  Map<String, dynamic>? _summary;
  List<dynamic> _lowStock = [];
  List<SaleModel> _recentSales = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiClient>();
    _service = ReportsService(api);
    _salesService = SalesService(api);
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1)
        .subtract(const Duration(milliseconds: 1));
    try {
      final results = await Future.wait([
        _service.getSalesSummary(startOfMonth, endOfMonth),
        _service.getLowStock(),
        _salesService.listSales(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as Map<String, dynamic>;
        _lowStock = results[1] as List;
        _recentSales = results[2] as List<SaleModel>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Atualizar',
              onPressed: _load),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(_error!,
                          style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 16),
                      OutlinedButton(
                          onPressed: _load,
                          child: const Text('Tentar novamente')),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Saudação
                      Text(
                        'Olá, ${user?.name.split(' ').first ?? ''}!',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _dateFormat.format(DateTime.now()),
                        style: const TextStyle(
                            color: AppColors.grey700, fontSize: 14),
                      ),
                      const SizedBox(height: 32),

                      // Resumo do mês
                      Text('Este mês',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (_summary != null) _TodaySummary(summary: _summary!),

                      const SizedBox(height: 32),

                      // Gráfico últimos 7 dias
                      Text('Vendas — últimos 7 dias',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _SalesChart(sales: _recentSales),

                      const SizedBox(height: 32),

                      // Ações rápidas
                      Text('Ações rápidas',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _QuickActions(isAdmin: user?.isAdmin ?? false),

                      // Alerta de estoque baixo
                      if (_lowStock.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            const Icon(Icons.warning_amber,
                                color: AppColors.error, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Estoque baixo (${_lowStock.length} variações)',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _LowStockAlert(items: _lowStock),
                      ],
                    ],
                  ),
                ),
    );
  }
}

// ── Resumo do dia ────────────────────────────────────

class _TodaySummary extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _TodaySummary({required this.summary});

  @override
  Widget build(BuildContext context) {
    final totalSales = summary['totalSales'] as int? ?? 0;
    final revenue = (summary['totalRevenueInCents'] as int? ?? 0) / 100;
    final discount = (summary['totalDiscountInCents'] as int? ?? 0) / 100;
    final net = (summary['netRevenueInCents'] as int? ?? 0) / 100;

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _SummaryCard(
          icon: Icons.receipt_long_outlined,
          label: 'Vendas',
          value: '$totalSales',
        ),
        _SummaryCard(
          icon: Icons.attach_money,
          label: 'Receita bruta',
          value: _currency.format(revenue),
        ),
        _SummaryCard(
          icon: Icons.discount_outlined,
          label: 'Descontos',
          value: _currency.format(discount),
        ),
        _SummaryCard(
          icon: Icons.trending_up,
          label: 'Receita líquida',
          value: _currency.format(net),
          highlight: true,
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: highlight ? AppColors.black : AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 18,
                    color: highlight ? AppColors.grey500 : AppColors.grey700),
                const SizedBox(width: 8),
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        color: highlight
                            ? AppColors.grey500
                            : AppColors.grey700)),
              ],
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: highlight ? AppColors.white : AppColors.black,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ações rápidas ────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final bool isAdmin;
  const _QuickActions({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _ActionButton(
          icon: Icons.point_of_sale,
          label: 'Nova Venda',
          onTap: () => context.go(AppRoutes.sales),
          primary: true,
        ),
        _ActionButton(
          icon: Icons.people_outline,
          label: 'Clientes',
          onTap: () => context.go(AppRoutes.customers),
        ),
        _ActionButton(
          icon: Icons.inventory_2_outlined,
          label: 'Produtos',
          onTap: () => context.go(AppRoutes.products),
        ),
        _ActionButton(
          icon: Icons.assignment_return_outlined,
          label: 'Devolução',
          onTap: () => context.go(AppRoutes.returns),
        ),
        if (isAdmin)
          _ActionButton(
            icon: Icons.bar_chart_outlined,
            label: 'Relatórios',
            onTap: () => context.go(AppRoutes.reports),
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 140,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: primary ? AppColors.black : AppColors.grey100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: primary ? AppColors.black : AppColors.grey300,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 28,
                color: primary ? AppColors.white : AppColors.black),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: primary ? AppColors.white : AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Alerta de estoque baixo ─────────────────────────

class _LowStockAlert extends StatelessWidget {
  final List<dynamic> items;
  const _LowStockAlert({required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: items.take(5).map((i) {
          final item = i as Map<String, dynamic>;
          return ListTile(
            leading: const Icon(Icons.warning_amber_outlined,
                color: AppColors.error, size: 20),
            title: Text(item['productName'] as String? ?? '',
                style: const TextStyle(fontSize: 14)),
            subtitle: Text(
                '${item['variantColor']} • ${item['variantSize']} • Cód. ${item['variantCode']}',
                style: const TextStyle(fontSize: 12)),
            trailing: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error),
              ),
              child: Text(
                '${item['currentStock']} un.',
                style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Gráfico de vendas diárias ─────────────────────────

class _SalesChart extends StatelessWidget {
  final List<SaleModel> sales;

  const _SalesChart({required this.sales});

  static final _dayLabels = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
  static final _tooltipCurrency =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  Widget build(BuildContext context) {
    // Group sales by UTC date string to match backend timestamp storage
    final dataMap = <String, double>{};
    for (final sale in sales) {
      final dt = DateTime.tryParse(sale.createdAt)?.toUtc();
      if (dt == null) continue;
      final dateStr = dt.toIso8601String().substring(0, 10);
      dataMap[dateStr] = (dataMap[dateStr] ?? 0) + sale.total;
    }

    final todayUtc = DateTime.now().toUtc();
    final days = List.generate(7, (i) => todayUtc.subtract(Duration(days: 6 - i)));

    final bars = days.asMap().entries.map((e) {
      final dateStr = e.value.toIso8601String().substring(0, 10);
      final value = dataMap[dateStr] ?? 0.0;
      final isToday = e.key == 6;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: value,
            color: isToday ? AppColors.black : AppColors.grey300,
            width: 28,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    final maxY = bars
        .map((b) => b.barRods.first.toY)
        .fold(0.0, (a, b) => a > b ? a : b);
    final chartMax = maxY == 0 ? 100.0 : maxY * 1.25;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: chartMax,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: chartMax / 4,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: AppColors.grey100, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 56,
                    interval: chartMax / 4,
                    getTitlesWidget: (value, _) => Text(
                      value == 0
                          ? ''
                          : value >= 1000
                              ? 'R\$${(value / 1000).toStringAsFixed(1)}k'
                              : 'R\$${value.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.grey700),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, _) {
                      final day = days[value.toInt()].toLocal();
                      final isToday = value.toInt() == 6;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _dayLabels[day.weekday % 7],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isToday
                                ? AppColors.black
                                : AppColors.grey700,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.black,
                  getTooltipItem: (_, _, rod, _) => BarTooltipItem(
                    _tooltipCurrency.format(rod.toY),
                    const TextStyle(
                        color: AppColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              barGroups: bars,
            ),
          ),
        ),
      ),
    );
  }
}
