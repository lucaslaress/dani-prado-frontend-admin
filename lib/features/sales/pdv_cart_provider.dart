import 'package:flutter/material.dart';

import '../customers/customer_model.dart';
import 'sale_model.dart';

class PdvCartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  final List<PaymentEntry> _paymentMethods = [];
  CustomerModel? _selectedCustomer;
  WalkInCustomer? _walkInCustomer;
  int _discountInCents = 0;

  // Getters
  List<CartItem> get items => List.unmodifiable(_items);
  List<PaymentEntry> get paymentMethods => List.unmodifiable(_paymentMethods);
  CustomerModel? get selectedCustomer => _selectedCustomer;
  WalkInCustomer? get walkInCustomer => _walkInCustomer;
  int get discountInCents => _discountInCents;

  // Cálculos do carrinho
  int get subtotalInCents =>
      _items.fold(0, (sum, item) => sum + item.totalInCents);

  int get appliedCreditInCents {
    if (_selectedCustomer == null || _selectedCustomer!.creditInCents <= 0) return 0;
    final afterDiscount = subtotalInCents - _discountInCents;
    if (afterDiscount <= 0) return 0;
    return _selectedCustomer!.creditInCents.clamp(0, afterDiscount);
  }

  int get totalInCents => subtotalInCents - _discountInCents - appliedCreditInCents;

  int get totalPaidInCents =>
      _paymentMethods.fold(0, (sum, p) => sum + p.amountInCents);

  int get remainingInCents => totalInCents - totalPaidInCents;

  bool get isFullyPaid => remainingInCents <= 0;
  bool get isEmpty => _items.isEmpty;

  // Itens
  void addItem(CartItem newItem) {
    final index =
        _items.indexWhere((i) => i.variantCode == newItem.variantCode);
    if (index >= 0) {
      _items[index].quantity++;
    } else {
      _items.add(newItem);
    }
    notifyListeners();
  }

  void removeItem(String variantCode) {
    _items.removeWhere((i) => i.variantCode == variantCode);
    notifyListeners();
  }

  void updateQuantity(String variantCode, int quantity) {
    if (quantity <= 0) {
      removeItem(variantCode);
      return;
    }
    final index = _items.indexWhere((i) => i.variantCode == variantCode);
    if (index >= 0) {
      _items[index].quantity = quantity;
      notifyListeners();
    }
  }

  // Cliente
  void setCustomer(CustomerModel customer) {
    _selectedCustomer = customer;
    _walkInCustomer = null;
    notifyListeners();
  }

  void setWalkInCustomer(WalkInCustomer customer) {
    _walkInCustomer = customer;
    _selectedCustomer = null;
    notifyListeners();
  }

  void clearCustomer() {
    _selectedCustomer = null;
    _walkInCustomer = null;
    notifyListeners();
  }

  // Desconto manual
  void setDiscount(int cents) {
    _discountInCents = cents.clamp(0, subtotalInCents);
    notifyListeners();
  }

  void clearDiscount() {
    _discountInCents = 0;
    notifyListeners();
  }

  // Pagamento
  void addPaymentMethod(PaymentEntry entry) {
    _paymentMethods.add(entry);
    notifyListeners();
  }

  void removePaymentMethod(int index) {
    _paymentMethods.removeAt(index);
    notifyListeners();
  }

  // Limpa o carrinho após venda finalizada
  void clear() {
    _items.clear();
    _paymentMethods.clear();
    _selectedCustomer = null;
    _walkInCustomer = null;
    _discountInCents = 0;
    notifyListeners();
  }
}
