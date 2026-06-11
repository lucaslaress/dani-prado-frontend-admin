import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/http/api_client.dart';
import '../../core/theme/app_theme.dart';
import 'product_form.dart';
import 'product_model.dart';
import 'products_service.dart';

final _currencyFormat =
    NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late final ProductsService _service;
  List<ProductModel> _products = [];
  bool _isLoading = true;
  String? _error;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _service = ProductsService(context.read<ApiClient>());
    _loadProducts();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ProductModel> get _filtered {
    if (_searchQuery.isEmpty) return _products;
    return _products
        .where((p) => p.name.toLowerCase().contains(_searchQuery))
        .toList();
  }

  Future<void> _deactivateProduct(ProductModel product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Desativar produto'),
        content: Text('Deseja desativar "${product.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Desativar',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _service.deactivateProduct(product.id);
      _loadProducts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final products = await _service.listProducts();
      if (!mounted) return;
      setState(() => _products = products);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produtos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: _loadProducts,
          ),
          FilledButton.icon(
            onPressed: () async {
              final created = await showProductForm(context);
              if (created != null) _loadProducts();
            },
            icon: const Icon(Icons.add),
            label: const Text('Novo produto'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.black,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Pesquisar por nome...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _loadProducts,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_products.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum produto cadastrado.',
          style: TextStyle(color: AppColors.grey700),
        ),
      );
    }

    final filtered = _filtered;

    if (filtered.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum produto encontrado.',
          style: TextStyle(color: AppColors.grey700),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _ProductCard(
        product: filtered[index],
        onEdit: () async {
          final updated =
              await showProductForm(context, product: filtered[index]);
          if (updated != null) _loadProducts();
        },
        onDeactivate: filtered[index].isActive
            ? () => _deactivateProduct(filtered[index])
            : null,
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onEdit;
  final VoidCallback? onDeactivate;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        childrenPadding: EdgeInsets.zero,
        leading: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: product.isActive ? AppColors.success : AppColors.grey300,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                product.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${product.totalStock} un.',
                  style: const TextStyle(fontSize: 12, color: AppColors.grey700),
                ),
                if (product.hasPromotion) ...[
                  Text(
                    _currencyFormat.format(product.basePrice),
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: AppColors.grey500,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    _currencyFormat.format(product.promotionalPrice),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ] else
                  Text(
                    _currencyFormat.format(product.basePrice),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Editar',
              onPressed: onEdit,
            ),
            if (onDeactivate != null)
              IconButton(
                icon: const Icon(Icons.block, size: 20, color: AppColors.grey500),
                tooltip: 'Desativar',
                onPressed: onDeactivate,
              ),
          ],
        ),
        subtitle: Text(
          product.category,
          style: const TextStyle(color: AppColors.grey700, fontSize: 13),
        ),
        children: [
          const Divider(height: 1),
          _VariantsTable(variants: product.variants),
        ],
      ),
    );
  }
}

class _VariantsTable extends StatelessWidget {
  final List<ProductVariant> variants;

  const _VariantsTable({required this.variants});

  @override
  Widget build(BuildContext context) {
    if (variants.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Sem variantes.', style: TextStyle(color: AppColors.grey500)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          const Row(
            children: [
              SizedBox(
                width: 80,
                child: Text('Código', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.grey700)),
              ),
              Expanded(
                child: Text('Cor', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.grey700)),
              ),
              SizedBox(
                width: 60,
                child: Text('Tam.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.grey700)),
              ),
              SizedBox(
                width: 60,
                child: Text('Estoque', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.grey700), textAlign: TextAlign.right),
              ),
              SizedBox(width: 24),
            ],
          ),
          const SizedBox(height: 6),
          for (final v in variants) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(v.code, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                  ),
                  Expanded(
                    child: Text(v.color, style: const TextStyle(fontSize: 13)),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(v.size, style: const TextStyle(fontSize: 13)),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${v.physicalStock}',
                      style: const TextStyle(fontSize: 13),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 24,
                    child: v.isActive
                        ? null
                        : const Tooltip(
                            message: 'Inativa',
                            child: Icon(Icons.block, size: 14, color: AppColors.grey500),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
