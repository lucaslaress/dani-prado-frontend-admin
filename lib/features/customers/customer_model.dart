class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final String cpf;
  final String description;
  final String status;
  final String createdAt;
  final String updatedAt;

  const CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.cpf,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 'active';

  // CPF formatado: 000.000.000-00
  String get formattedCpf {
    final digits = cpf.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11) return cpf;
    return '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6, 9)}-${digits.substring(9)}';
  }

  // Telefone formatado: (00) 00000-0000
  String get formattedPhone {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
    }
    if (digits.length == 10) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6)}';
    }
    return phone;
  }

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      cpf: json['cpf'] as String,
      description: json['description'] as String? ?? '',
      status: json['status'] as String,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }
}
