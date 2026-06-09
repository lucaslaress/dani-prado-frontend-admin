import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/http/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../reports/reports_service.dart';
import 'seller_form.dart';
import 'users_service.dart';

final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late final UsersService _usersService;
  late final ReportsService _reportsService;

  List<UserModel> _sellers = [];
  // sellerId → {totalSales, totalRevenueInCents}
  Map<String, Map<String, dynamic>> _sellerStats = {};
  bool _statsLoaded = false; // true somente se a chamada by-seller teve sucesso
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiClient>();
    _usersService = UsersService(api);
    _reportsService = ReportsService(api);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 1)
          .subtract(const Duration(milliseconds: 1));

      final sellers = await _usersService.listSellers();

      // Busca stats por vendedor — falha silenciosa se não tiver permissão
      Map<String, Map<String, dynamic>> stats = {};
      bool statsLoaded = false;
      try {
        final bySellerList =
            await _reportsService.getSalesBySeller(startOfMonth, endOfMonth);
        for (final entry in bySellerList) {
          final map = entry as Map<String, dynamic>;
          stats[map['sellerId'] as String] = map;
        }
        statsLoaded = true;
      } catch (_) {}

      setState(() {
        _sellers = sellers;
        _sellerStats = stats;
        _statsLoaded = statsLoaded;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleStatus(UserModel seller) async {
    final newStatus = seller.status == 'active' ? 'inactive' : 'active';
    try {
      await _usersService.updateSeller(seller.uid, {'status': newStatus});
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuários'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          FilledButton.icon(
            onPressed: () async {
              final created = await showSellerForm(context);
              if (created != null) _load();
            },
            icon: const Icon(Icons.add),
            label: const Text('Novo vendedor'),
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
              : _sellers.isEmpty
                  ? const Center(
                      child: Text('Nenhum vendedor cadastrado.',
                          style: TextStyle(color: AppColors.grey700)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: _sellers.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _SellerCard(
                        seller: _sellers[i],
                        stats: _statsLoaded
                            ? (_sellerStats[_sellers[i].uid] ??
                                {'totalSales': 0, 'totalRevenueInCents': 0})
                            : null,
                        onToggle: () => _toggleStatus(_sellers[i]),
                      ),
                    ),
    );
  }
}

class _SellerCard extends StatelessWidget {
  final UserModel seller;
  final Map<String, dynamic>? stats;
  final VoidCallback onToggle;
  const _SellerCard(
      {required this.seller, required this.stats, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isActive = seller.status == 'active';
    final totalSales = stats?['totalSales'] as int? ?? 0;
    final revenueInCents = stats?['totalRevenueInCents'] as int? ?? 0;
    final hasStats = stats != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? AppColors.success : AppColors.grey300,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(seller.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(seller.email,
                      style: const TextStyle(
                          color: AppColors.grey700, fontSize: 13)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: seller.permissions
                        .map((p) => _PermissionChip(label: p))
                        .toList(),
                  ),
                ],
              ),
            ),
            if (hasStats) ...[
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currency.format(revenueInCents / 100),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    '$totalSales venda${totalSales != 1 ? 's' : ''} este mês',
                    style: const TextStyle(
                        color: AppColors.grey700, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
            TextButton(
              onPressed: onToggle,
              child: Text(
                isActive ? 'Desativar' : 'Ativar',
                style: TextStyle(
                  color: isActive ? AppColors.error : AppColors.success,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionChip extends StatelessWidget {
  final String label;
  const _PermissionChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.grey300),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 11, color: AppColors.grey700)),
    );
  }
}
