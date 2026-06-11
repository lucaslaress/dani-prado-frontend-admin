import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/http/api_client.dart';
import '../../core/theme/app_theme.dart';
import 'customer_form.dart';
import 'customer_model.dart';
import 'customers_service.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  late final CustomersService _service;
  final _searchController = TextEditingController();

  List<CustomerModel> _customers = [];
  bool _isLoading = true;
  String? _error;

  List<CustomerModel> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _customers;
    final digits = q.replaceAll(RegExp(r'\D'), '');
    return _customers.where((c) {
      if (c.name.toLowerCase().contains(q)) return true;
      if (digits.isNotEmpty && c.cpf.contains(digits)) return true;
      if (digits.isNotEmpty && c.phone.contains(digits)) return true;
      return false;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _service = CustomersService(context.read<ApiClient>());
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final customers = await _service.listCustomers();
      setState(() => _customers = customers);
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
        title: const Text('Clientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: _loadCustomers,
          ),
          FilledButton.icon(
            onPressed: () async {
              final created = await showCustomerForm(context);
              if (created != null) _loadCustomers();
            },
            icon: const Icon(Icons.add),
            label: const Text('Novo cliente'),
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
          _buildSearchBar(),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          hintText: 'Buscar por nome, CPF ou telefone...',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (_) => setState(() {}),
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
              onPressed: _loadCustomers,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    final list = _filtered;

    if (list.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum cliente encontrado.',
          style: TextStyle(color: AppColors.grey700),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _CustomerCard(
        customer: list[index],
        onEdit: () async {
          final updated =
              await showCustomerForm(context, customer: list[index]);
          if (updated != null) _loadCustomers();
        },
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final CustomerModel customer;
  final VoidCallback onEdit;
  const _CustomerCard({required this.customer, required this.onEdit});

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
                color:
                    customer.isActive ? AppColors.success : AppColors.grey300,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    customer.formattedCpf,
                    style: const TextStyle(color: AppColors.grey700, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              customer.formattedPhone,
              style: const TextStyle(fontSize: 13),
            ),
            if (customer.creditInCents > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined,
                        size: 13, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(
                      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
                          .format(customer.credit),
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
            if (customer.description.isNotEmpty) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (dialogContext) => Dialog(
                    child: SizedBox(
                      width: 320,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(customer.name,
                                style: Theme.of(dialogContext)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Text(customer.description),
                            const SizedBox(height: 20),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                child: const Text('Fechar'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Descrição', style: TextStyle(fontSize: 12)),
              ),
            ],
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Editar',
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    );
  }
}
