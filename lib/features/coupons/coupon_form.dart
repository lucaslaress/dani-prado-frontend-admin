import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/http/api_client.dart';
import '../../core/theme/app_theme.dart';
import 'coupon_model.dart';
import 'coupons_service.dart';

Future<CouponModel?> showCouponForm(BuildContext context) {
  return showDialog<CouponModel>(
    context: context,
    barrierDismissible: false,
    builder: (_) => CouponForm(
      service: CouponsService(context.read<ApiClient>()),
    ),
  );
}

class CouponForm extends StatefulWidget {
  final CouponsService service;
  const CouponForm({super.key, required this.service});

  @override
  State<CouponForm> createState() => _CouponFormState();
}

class _CouponFormState extends State<CouponForm> {
  final _formKey = GlobalKey<FormState>();

  final _codeController = TextEditingController();
  final _valueController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _maxUsesController = TextEditingController();

  String _discountType = 'percentage'; // 'percentage' | 'fixed'
  DateTime _startsAt = DateTime.now();
  DateTime? _expiresAt;

  bool _isLoading = false;
  String? _error;

  static final _dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');

  @override
  void dispose() {
    _codeController.dispose();
    _valueController.dispose();
    _minOrderController.dispose();
    _maxUsesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isExpiry}) async {
    final now = DateTime.now();
    final initial = isExpiry ? (_expiresAt ?? _startsAt.add(const Duration(days: 30))) : _startsAt;
    final first = isExpiry ? _startsAt.add(const Duration(days: 1)) : now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (picked == null) return;

    setState(() {
      if (isExpiry) {
        _expiresAt = picked;
      } else {
        _startsAt = picked;
        // Se a data de expiração ficou antes do novo início, limpa
        if (_expiresAt != null && !_expiresAt!.isAfter(_startsAt)) {
          _expiresAt = null;
        }
      }
    });
  }

  int _parseCents(String value) {
    final cleaned = value.trim().replaceAll(',', '.');
    final reais = double.tryParse(cleaned) ?? 0;
    return (reais * 100).round();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final rawValue = _valueController.text.trim();
      final int discountValue;
      if (_discountType == 'percentage') {
        discountValue = int.parse(rawValue);
      } else {
        discountValue = _parseCents(rawValue);
      }

      final body = <String, dynamic>{
        'code': _codeController.text.trim().toUpperCase(),
        'discountType': _discountType,
        'discountValue': discountValue,
        'startsAt': _startsAt.toIso8601String(),
      };

      final minText = _minOrderController.text.trim();
      if (minText.isNotEmpty) {
        body['minimumOrderInCents'] = _parseCents(minText);
      }

      final maxText = _maxUsesController.text.trim();
      if (maxText.isNotEmpty) {
        body['maxUses'] = int.parse(maxText);
      }

      if (_expiresAt != null) {
        body['expiresAt'] = _expiresAt!.toIso8601String();
      }

      final coupon = await widget.service.createCoupon(body);
      if (mounted) Navigator.of(context).pop(coupon);
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
        width: 520,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Novo cupom',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                // Código
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9]')),
                    LengthLimitingTextInputFormatter(20),
                    _UpperCaseFormatter(),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Código do cupom',
                    hintText: 'Ex: VERAO10',
                  ),
                  validator: (v) {
                    final trimmed = v?.trim() ?? '';
                    if (trimmed.length < 3) {
                      return 'Mínimo de 3 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Tipo de desconto
                const Text(
                  'Tipo de desconto',
                  style: TextStyle(fontSize: 13, color: AppColors.grey700),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'percentage',
                      label: Text('Percentual (%)'),
                      icon: Icon(Icons.percent),
                    ),
                    ButtonSegment(
                      value: 'fixed',
                      label: Text('Valor fixo (R\$)'),
                      icon: Icon(Icons.attach_money),
                    ),
                  ],
                  selected: {_discountType},
                  onSelectionChanged: (s) => setState(() {
                    _discountType = s.first;
                    _valueController.clear();
                  }),
                ),
                const SizedBox(height: 16),

                // Valor do desconto
                TextFormField(
                  controller: _valueController,
                  keyboardType: _discountType == 'percentage'
                      ? TextInputType.number
                      : const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: _discountType == 'percentage'
                      ? [FilteringTextInputFormatter.digitsOnly]
                      : [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[\d,.]')),
                        ],
                  decoration: InputDecoration(
                    labelText: _discountType == 'percentage'
                        ? 'Desconto (%)'
                        : 'Valor do desconto (R\$)',
                    hintText:
                        _discountType == 'percentage' ? '10' : '0,00',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Campo obrigatório';
                    }
                    if (_discountType == 'percentage') {
                      final n = int.tryParse(v.trim());
                      if (n == null || n < 1 || n > 100) {
                        return 'Percentual deve ser entre 1 e 100';
                      }
                    } else {
                      if (_parseCents(v) <= 0) {
                        return 'Informe um valor válido';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Pedido mínimo e usos máximos lado a lado
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minOrderController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[\d,.]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Pedido mínimo (R\$)',
                          hintText: 'Opcional',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _maxUsesController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Usos máximos',
                          hintText: 'Opcional',
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return null;
                          final n = int.tryParse(v);
                          if (n == null || n < 1) {
                            return 'Deve ser ao menos 1';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Datas
                const Text(
                  'Período de validade',
                  style: TextStyle(fontSize: 13, color: AppColors.grey700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _DatePickerField(
                        label: 'Início',
                        value: _startsAt,
                        onTap: () => _pickDate(isExpiry: false),
                        dateFormat: _dateFormat,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _DatePickerField(
                        label: 'Expiração (opcional)',
                        value: _expiresAt,
                        onTap: () => _pickDate(isExpiry: true),
                        dateFormat: _dateFormat,
                        clearable: true,
                        onClear: () => setState(() => _expiresAt = null),
                      ),
                    ),
                  ],
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!,
                      style: const TextStyle(color: AppColors.error)),
                ],

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
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
                          : const Text('Criar cupom'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Campo de data que abre o DatePicker ao tocar
class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final DateFormat dateFormat;
  final bool clearable;
  final VoidCallback? onClear;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.dateFormat,
    this.clearable = false,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: clearable && value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  padding: EdgeInsets.zero,
                  onPressed: onClear,
                )
              : const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          value != null ? dateFormat.format(value!) : '—',
          style: TextStyle(
            color: value != null ? AppColors.black : AppColors.grey500,
          ),
        ),
      ),
    );
  }
}

// Converte texto para maiúsculas em tempo real
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
