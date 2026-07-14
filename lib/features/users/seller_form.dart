import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/http/api_client.dart';
import '../../core/theme/app_theme.dart';
import 'users_service.dart';

Future<UserModel?> showSellerForm(BuildContext context) {
  return showDialog<UserModel>(
    context: context,
    barrierDismissible: false,
    builder: (_) => SellerForm(
      service: UsersService(context.read<ApiClient>()),
    ),
  );
}

// Grupos de permissões para exibição organizada
class _PermGroup {
  final String title;
  final List<_Perm> perms;
  const _PermGroup(this.title, this.perms);
}

class _Perm {
  final String value;
  final String label;
  const _Perm(this.value, this.label);
}

const _permGroups = [
  _PermGroup('Produtos', [
    _Perm('products:read', 'Ver produtos'),
    _Perm('products:create', 'Criar produtos'),
    _Perm('products:update', 'Editar produtos'),
    _Perm('products:deactivate', 'Desativar produtos'),
    _Perm('products:read_cost_price', 'Ver preço de custo'),
  ]),
  _PermGroup('Clientes', [
    _Perm('customers:read', 'Ver clientes'),
    _Perm('customers:create', 'Criar clientes'),
    _Perm('customers:update', 'Editar clientes'),
  ]),
  _PermGroup('Vendas', [
    _Perm('sales:create', 'Realizar vendas'),
    _Perm('sales:read_own', 'Ver próprias vendas'),
    _Perm('sales:read_all', 'Ver todas as vendas'),
  ]),
  _PermGroup('Devoluções', [
    _Perm('returns:create', 'Registrar devoluções'),
    _Perm('returns:read', 'Ver devoluções'),
  ]),
  _PermGroup('Cupons', [
    _Perm('coupons:read', 'Ver cupons'),
    _Perm('coupons:create', 'Criar cupons'),
    _Perm('coupons:update', 'Editar cupons'),
    _Perm('coupons:deactivate', 'Desativar cupons'),
  ]),
  _PermGroup('Relatórios', [
    _Perm('reports:read_own_sales', 'Ver próprio relatório'),
    _Perm('reports:read_store', 'Ver relatório da loja'),
  ]),
];

// Todas as permissões em lista plana — para "selecionar todas"
final _allPerms =
    _permGroups.expand((g) => g.perms).map((p) => p.value).toList();

class SellerForm extends StatefulWidget {
  final UsersService service;
  const SellerForm({super.key, required this.service});

  @override
  State<SellerForm> createState() => _SellerFormState();
}

class _SellerFormState extends State<SellerForm> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final Set<String> _permissions = {};
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _toggleAll() {
    setState(() {
      if (_permissions.length == _allPerms.length) {
        _permissions.clear();
      } else {
        _permissions.addAll(_allPerms);
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final seller = await widget.service.createSeller({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim().toLowerCase(),
        'password': _passwordController.text,
        'permissions': _permissions.toList(),
      });
      if (mounted) Navigator.of(context).pop(seller);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 580,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 680),
          child: Column(
            children: [
              _buildHeader(context),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAccountSection(),
                        const SizedBox(height: 24),
                        _buildPermissionsSection(),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(_error!,
                              style:
                                  const TextStyle(color: AppColors.error)),
                        ],
                      ],
                    ),
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
            'Novo vendedor',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dados da conta',
          style: TextStyle(
              fontWeight: FontWeight.w600, color: AppColors.grey700),
        ),
        const SizedBox(height: 12),

        // Nome
        TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nome completo'),
          validator: (v) {
            if (v == null || v.trim().length < 2) {
              return 'Nome deve ter pelo menos 2 caracteres';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // E-mail
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'E-mail'),
          validator: (v) {
            final email = v?.trim() ?? '';
            if (!RegExp(r'^[\w\.\-]+@[\w\-]+\.\w+$').hasMatch(email)) {
              return 'E-mail inválido';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Senha e confirmação lado a lado
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.length < 6) {
                    return 'Mínimo 6 caracteres';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirmar senha',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setState(
                        () => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) {
                  if (v != _passwordController.text) {
                    return 'Senhas não coincidem';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPermissionsSection() {
    final allSelected = _permissions.length == _allPerms.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Permissões',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: AppColors.grey700),
            ),
            const Spacer(),
            TextButton(
              onPressed: _toggleAll,
              child: Text(allSelected ? 'Limpar todas' : 'Selecionar todas'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._permGroups.map((group) => _PermGroupWidget(
              group: group,
              selected: _permissions,
              onToggle: (value) => setState(() {
                if (_permissions.contains(value)) {
                  _permissions.remove(value);
                } else {
                  _permissions.add(value);
                }
              }),
            )),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.white),
                  )
                : const Text('Cadastrar'),
          ),
        ],
      ),
    );
  }
}

// Grupo de checkboxes de permissões
class _PermGroupWidget extends StatelessWidget {
  final _PermGroup group;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _PermGroupWidget({
    required this.group,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.title,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.grey500,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 0,
            runSpacing: 0,
            children: group.perms
                .map((perm) => SizedBox(
                      width: 240,
                      child: CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(perm.label,
                            style: const TextStyle(fontSize: 13)),
                        value: selected.contains(perm.value),
                        onChanged: (_) => onToggle(perm.value),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
