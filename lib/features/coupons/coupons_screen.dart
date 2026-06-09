import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/http/api_client.dart';
import '../../core/theme/app_theme.dart';
import 'coupon_form.dart';
import 'coupon_model.dart';
import 'coupons_service.dart';

class CouponsScreen extends StatefulWidget {
  const CouponsScreen({super.key});

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  late final CouponsService _service;
  List<CouponModel> _coupons = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = CouponsService(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _service.listCoupons();
      setState(() => _coupons = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deactivate(CouponModel coupon) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Desativar cupom'),
        content: Text('Deseja desativar o cupom "${coupon.code}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Desativar', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _service.deactivateCoupon(coupon.code);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cupons'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          FilledButton.icon(
            onPressed: () async {
              final created = await showCouponForm(context);
              if (created != null) _load();
            },
            icon: const Icon(Icons.add),
            label: const Text('Novo cupom'),
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
                          onPressed: _load, child: const Text('Tentar novamente')),
                    ],
                  ),
                )
              : _coupons.isEmpty
                  ? const Center(
                      child: Text('Nenhum cupom cadastrado.',
                          style: TextStyle(color: AppColors.grey700)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: _coupons.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _CouponCard(
                        coupon: _coupons[i],
                        onDeactivate: () => _deactivate(_coupons[i]),
                      ),
                    ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  final CouponModel coupon;
  final VoidCallback onDeactivate;
  const _CouponCard({required this.coupon, required this.onDeactivate});

  @override
  Widget build(BuildContext context) {
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
                color: coupon.isActive ? AppColors.success : AppColors.grey300,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(coupon.code,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(coupon.discountLabel,
                      style: const TextStyle(
                          color: AppColors.grey700, fontSize: 13)),
                  if (coupon.maxUses != null)
                    Text(
                        'Usos: ${coupon.currentUses} / ${coupon.maxUses}',
                        style: const TextStyle(
                            color: AppColors.grey500, fontSize: 12)),
                ],
              ),
            ),
            if (coupon.isActive)
              TextButton(
                onPressed: onDeactivate,
                child: const Text('Desativar',
                    style: TextStyle(color: AppColors.error)),
              ),
          ],
        ),
      ),
    );
  }
}
