import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/http/api_client.dart';
import '../../core/theme/app_theme.dart';
import 'product_model.dart';
import 'products_service.dart';

class _CurrencyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
          text: '', selection: TextSelection.collapsed(offset: 0));
    }
    final cents = int.parse(digits);
    final formatted =
        (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

Future<ProductModel?> showProductForm(BuildContext context,
    {ProductModel? product}) {
  return showDialog<ProductModel>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ProductForm(
      service: ProductsService(context.read<ApiClient>()),
      product: product,
    ),
  );
}

// Estado rascunho de cada variante antes de enviar
class _VariantDraft {
  final codeController = TextEditingController();
  final colorController = TextEditingController();
  final sizeController = TextEditingController();
  final stockController = TextEditingController(text: '0');
  // Preserva o status original da variante ao editar (null = variante nova)
  final String? originalStatus;

  _VariantDraft({this.originalStatus});

  factory _VariantDraft.fromVariant(ProductVariant variant) {
    final draft = _VariantDraft(originalStatus: variant.status);
    draft.codeController.text = variant.code;
    draft.colorController.text = variant.color;
    draft.sizeController.text = variant.size;
    draft.stockController.text = variant.physicalStock.toString();
    return draft;
  }

  void dispose() {
    codeController.dispose();
    colorController.dispose();
    sizeController.dispose();
    stockController.dispose();
  }
}

class ProductForm extends StatefulWidget {
  final ProductsService service;
  final ProductModel? product; // null = criar, não-null = editar

  const ProductForm({super.key, required this.service, this.product});

  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _basePriceController = TextEditingController();
  final _promoPriceController = TextEditingController();

  final List<_VariantDraft> _variants = [];

  bool _isLoading = false;
  String? _error;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      // Modo edição: preenche todos os campos com os dados existentes
      _nameController.text = p.name;
      _descriptionController.text = p.description;
      _categoryController.text = p.category;
      _basePriceController.text = (p.basePriceInCents / 100)
          .toStringAsFixed(2)
          .replaceAll('.', ',');
      if (p.promotionalPriceInCents != null) {
        _promoPriceController.text = (p.promotionalPriceInCents! / 100)
            .toStringAsFixed(2)
            .replaceAll('.', ',');
      }
      for (final v in p.variants) {
        _variants.add(_VariantDraft.fromVariant(v));
      }
    } else {
      _addVariant(); // modo criação: começa com uma variante em branco
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _basePriceController.dispose();
    _promoPriceController.dispose();
    for (final v in _variants) {
      v.dispose();
    }
    super.dispose();
  }

  void _addVariant() {
    setState(() => _variants.add(_VariantDraft()));
  }

  void _removeVariant(int index) {
    setState(() {
      _variants[index].dispose();
      _variants.removeAt(index);
    });
  }

  int _parseCents(String value) {
    final cleaned = value.trim().replaceAll(',', '.');
    final reais = double.tryParse(cleaned) ?? 0;
    return (reais * 100).round();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final baseCents = _parseCents(_basePriceController.text);
    final promoText = _promoPriceController.text.trim();
    final promoCents = promoText.isEmpty ? null : _parseCents(promoText);

    if (promoCents != null && promoCents >= baseCents) {
      setState(
          () => _error = 'Preço promocional deve ser menor que o preço base');
      return;
    }

    // Verifica códigos de variante duplicados
    final codes = _variants.map((v) => v.codeController.text.trim()).toList();
    if (codes.toSet().length != codes.length) {
      setState(() => _error = 'Existem variantes com o mesmo código');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final variants = _variants
          .map((v) => {
                // Em edição, envia o código para identificar a variante existente
                if (_isEditing && v.codeController.text.trim().isNotEmpty)
                  'code': v.codeController.text.trim(),
                'color': v.colorController.text.trim(),
                'size': v.sizeController.text.trim(),
                'stock': {
                  'physicalStore':
                      int.tryParse(v.stockController.text.trim()) ?? 0,
                },
                if (v.originalStatus != null) 'status': v.originalStatus,
              })
          .toList();

      final body = <String, dynamic>{
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _categoryController.text.trim(),
        'basePriceInCents': baseCents,
        'variants': variants,
      };
      if (!_isEditing) body['images'] = <String>[];
      if (promoCents != null) {
        body['promotionalPriceInCents'] = promoCents;
      } else if (_isEditing) {
        body['promotionalPriceInCents'] = null; // limpa promoção se campo vazio
      }

      final product = _isEditing
          ? await widget.service.updateProduct(widget.product!.id, body)
          : await widget.service.createProduct(body);
      if (mounted) Navigator.of(context).pop(product);
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
        width: 640,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 680),
          child: Column(
            children: [
              // Cabeçalho fixo
              _buildHeader(context),
              const Divider(height: 1),

              // Conteúdo rolável
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoSection(),
                        const SizedBox(height: 24),
                        _buildPriceSection(),
                        const SizedBox(height: 24),
                        _buildVariantsSection(),
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

              // Rodapé fixo com botões
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
            _isEditing ? 'Editar produto' : 'Novo produto',
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

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Informações gerais',
            style:
                TextStyle(fontWeight: FontWeight.w600, color: AppColors.grey700)),
        const SizedBox(height: 12),
        TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nome do produto'),
          validator: (v) {
            if (v == null || v.trim().length < 2) {
              return 'Nome deve ter pelo menos 2 caracteres';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Descrição',
            alignLabelWithHint: true,
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Descrição é obrigatória';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _categoryController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Categoria',
            hintText: 'Ex: Vestidos, Blusas, Calças...',
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Categoria é obrigatória';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPriceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Preços',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.grey700)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _basePriceController,
                keyboardType: TextInputType.number,
                inputFormatters: [_CurrencyFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Preço base (R\$)',
                  hintText: '0,00',
                ),
                validator: (v) {
                  final cents = _parseCents(v ?? '');
                  if (cents <= 0) return 'Informe um preço válido';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _promoPriceController,
                keyboardType: TextInputType.number,
                inputFormatters: [_CurrencyFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Preço promocional (R\$)',
                  hintText: 'Opcional',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVariantsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Variantes',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.grey700)),
            const Spacer(),
            TextButton.icon(
              onPressed: _addVariant,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Adicionar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Column(
          children: [
            for (int i = 0; i < _variants.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _VariantRow(
                key: ValueKey(_variants[i]),
                draft: _variants[i],
                index: i,
                showCode: _isEditing && _variants[i].originalStatus != null,
                canRemove: _variants.length > 1,
                onRemove: () => _removeVariant(i),
              ),
            ],
          ],
        ),
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
                : Text(_isEditing ? 'Salvar' : 'Cadastrar'),
          ),
        ],
      ),
    );
  }
}

// Widget para cada linha de variante
class _VariantRow extends StatelessWidget {
  final _VariantDraft draft;
  final int index;
  final bool showCode;
  final bool canRemove;
  final VoidCallback onRemove;

  const _VariantRow({
    super.key,
    required this.draft,
    required this.index,
    required this.showCode,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.grey300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Variante ${index + 1}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const Spacer(),
              if (canRemove)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppColors.grey700),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Remover variante',
                  onPressed: onRemove,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (showCode) ...[
                // Código gerado pelo backend — exibido apenas em edição
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    controller: draft.codeController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Código',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              // Cor
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: draft.colorController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Cor',
                    hintText: 'Ex: Preto',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Obrigatória';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Tamanho
              SizedBox(
                width: 140,
                child: TextFormField(
                  controller: draft.sizeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Tamanho',
                    hintText: 'M',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Obrigatório';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Estoque
              SizedBox(
                width: 90,
                child: TextFormField(
                  controller: draft.stockController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Estoque',
                  ),
                  validator: (v) {
                    if (int.tryParse(v ?? '') == null) return 'Inválido';
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
