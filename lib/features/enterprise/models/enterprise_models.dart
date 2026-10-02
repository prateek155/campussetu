// lib/features/enterprise/models/enterprise_models.dart

class EnterpriseStoreProfile {
  final String ownerName;
  final String restaurantName;
  final String mobileNumber;
  final String email;
  final String city;
  final String state;
  final String upiId;
  final double gstPercent;
  final int tablesCount;
  final String billPrefix;
  final String theme;
  final bool notificationsEnabled;
  final Map<String, bool> enabledModules;

  const EnterpriseStoreProfile({
    this.ownerName = '',
    this.restaurantName = 'Naya restaurant',
    this.mobileNumber = '',
    this.email = '',
    this.city = '',
    this.state = '',
    this.upiId = '',
    this.gstPercent = 5.0,
    this.tablesCount = 8,
    this.billPrefix = 'POS',
    this.theme = 'Auto',
    this.notificationsEnabled = true,
    this.enabledModules = const {
      'inventory': true,
      'udhaar': true,
      'staff': true,
      'redeem': true,
      'reports': true,
    },
  });

  bool get isProfileComplete =>
      ownerName.trim().isNotEmpty &&
      restaurantName.trim().isNotEmpty &&
      restaurantName != 'Naya restaurant';

  EnterpriseStoreProfile copyWith({
    String? ownerName,
    String? restaurantName,
    String? mobileNumber,
    String? email,
    String? city,
    String? state,
    String? upiId,
    double? gstPercent,
    int? tablesCount,
    String? billPrefix,
    String? theme,
    bool? notificationsEnabled,
    Map<String, bool>? enabledModules,
  }) {
    return EnterpriseStoreProfile(
      ownerName: ownerName ?? this.ownerName,
      restaurantName: restaurantName ?? this.restaurantName,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      email: email ?? this.email,
      city: city ?? this.city,
      state: state ?? this.state,
      upiId: upiId ?? this.upiId,
      gstPercent: gstPercent ?? this.gstPercent,
      tablesCount: tablesCount ?? this.tablesCount,
      billPrefix: billPrefix ?? this.billPrefix,
      theme: theme ?? this.theme,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      enabledModules: enabledModules ?? this.enabledModules,
    );
  }

  Map<String, dynamic> toJson() => {
    'owner_name': ownerName,
    'restaurant_name': restaurantName,
    'mobile_number': mobileNumber,
    'email': email,
    'city': city,
    'state': state,
    'upi_id': upiId,
    'gst_percent': gstPercent,
    'tables_count': tablesCount,
    'bill_prefix': billPrefix,
    'theme': theme,
    'notifications_enabled': notificationsEnabled,
    'enabled_modules': enabledModules,
  };

  factory EnterpriseStoreProfile.fromJson(Map<String, dynamic> json) {
    Map<String, bool> modules = {
      'inventory': true,
      'udhaar': true,
      'staff': true,
      'redeem': true,
      'reports': true,
    };
    if (json['enabled_modules'] is Map) {
      final raw = json['enabled_modules'] as Map;
      raw.forEach((k, v) {
        modules[k.toString()] = v == true;
      });
    }

    return EnterpriseStoreProfile(
      ownerName: json['owner_name']?.toString() ?? '',
      restaurantName: json['restaurant_name']?.toString() ?? 'Naya restaurant',
      mobileNumber: json['mobile_number']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      upiId: json['upi_id']?.toString() ?? '',
      gstPercent: (json['gst_percent'] as num?)?.toDouble() ?? 5.0,
      tablesCount: (json['tables_count'] as num?)?.toInt() ?? 8,
      billPrefix: json['bill_prefix']?.toString() ?? 'POS',
      theme: json['theme']?.toString() ?? 'Auto',
      notificationsEnabled: json['notifications_enabled'] != false,
      enabledModules: modules,
    );
  }
}

class FoodItem {
  final String id;
  final String name;
  final String category;
  final double price;

  const FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'price': price,
  };

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
    id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    name: json['name']?.toString() ?? '',
    category: json['category']?.toString() ?? 'Main',
    price: (json['price'] as num?)?.toDouble() ?? 0.0,
  );
}

class BillItem {
  final String name;
  final double price;
  int quantity;

  BillItem({
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  double get total => price * quantity;

  Map<String, dynamic> toJson() => {
    'name': name,
    'price': price,
    'quantity': quantity,
    'total': total,
  };

  factory BillItem.fromJson(Map<String, dynamic> json) => BillItem(
    name: json['name']?.toString() ?? '',
    price: (json['price'] as num?)?.toDouble() ?? 0.0,
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
  );
}

class EnterpriseBill {
  final String id;
  final String billNumber;
  final String tableNumber;
  final List<BillItem> items;
  final double subtotal;
  final double gstPercent;
  final double gstAmount;
  final double totalAmount;
  final String paymentMode; // 'Cash' | 'UPI'
  final DateTime createdAt;

  const EnterpriseBill({
    required this.id,
    required this.billNumber,
    required this.tableNumber,
    required this.items,
    required this.subtotal,
    required this.gstPercent,
    required this.gstAmount,
    required this.totalAmount,
    required this.paymentMode,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'bill_number': billNumber,
    'table_number': tableNumber,
    'items': items.map((e) => e.toJson()).toList(),
    'subtotal': subtotal,
    'gst_percent': gstPercent,
    'gst_amount': gstAmount,
    'total_amount': totalAmount,
    'payment_mode': paymentMode,
    'created_at': createdAt.toIso8601String(),
  };

  factory EnterpriseBill.fromJson(Map<String, dynamic> json) {
    List<BillItem> itemsList = [];
    if (json['items'] is List) {
      itemsList = (json['items'] as List)
          .map((i) => BillItem.fromJson(i as Map<String, dynamic>))
          .toList();
    }
    return EnterpriseBill(
      id: json['id']?.toString() ?? '',
      billNumber: json['bill_number']?.toString() ?? '',
      tableNumber: json['table_number']?.toString() ?? 'Table 1',
      items: itemsList,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      gstPercent: (json['gst_percent'] as num?)?.toDouble() ?? 5.0,
      gstAmount: (json['gst_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMode: json['payment_mode']?.toString() ?? 'Cash',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class InventoryItem {
  final String id;
  final String itemName;
  final double quantity;
  final double amount;
  final String vendor;
  final String purchaseDate;

  const InventoryItem({
    required this.id,
    required this.itemName,
    required this.quantity,
    required this.amount,
    required this.vendor,
    required this.purchaseDate,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'item_name': itemName,
    'quantity': quantity,
    'amount': amount,
    'vendor': vendor,
    'purchase_date': purchaseDate,
  };

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
    id: json['id']?.toString() ?? '',
    itemName: json['item_name']?.toString() ?? '',
    quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
    amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    vendor: json['vendor']?.toString() ?? '',
    purchaseDate: json['purchase_date']?.toString() ?? '',
  );
}

class UdhaarRecord {
  final String id;
  final String customerName;
  final double amount;
  final String type; // 'given' or 'repaid'
  final String transactionDate;
  final String notes;

  const UdhaarRecord({
    required this.id,
    required this.customerName,
    required this.amount,
    required this.type,
    required this.transactionDate,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'customer_name': customerName,
    'amount': amount,
    'type': type,
    'transaction_date': transactionDate,
    'notes': notes,
  };

  factory UdhaarRecord.fromJson(Map<String, dynamic> json) => UdhaarRecord(
    id: json['id']?.toString() ?? '',
    customerName: json['customer_name']?.toString() ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    type: json['type']?.toString() ?? 'given',
    transactionDate: json['transaction_date']?.toString() ?? '',
    notes: json['notes']?.toString() ?? '',
  );
}

class StaffAdvance {
  final String id;
  final String staffId;
  final double amount;
  final String advanceDate;
  final String notes;

  const StaffAdvance({
    required this.id,
    required this.staffId,
    required this.amount,
    required this.advanceDate,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'staff_id': staffId,
    'amount': amount,
    'advance_date': advanceDate,
    'notes': notes,
  };

  factory StaffAdvance.fromJson(Map<String, dynamic> json) => StaffAdvance(
    id: json['id']?.toString() ?? '',
    staffId: json['staff_id']?.toString() ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    advanceDate: json['advance_date']?.toString() ?? '',
    notes: json['notes']?.toString() ?? '',
  );
}

class StaffMember {
  final String id;
  final String name;
  final String post;
  final double salary;
  final String joiningDate;
  final List<StaffAdvance> advances;

  const StaffMember({
    required this.id,
    required this.name,
    required this.post,
    required this.salary,
    required this.joiningDate,
    this.advances = const [],
  });

  double get totalAdvance => advances.fold(0.0, (acc, a) => acc + a.amount);
  double get netSalary => (salary - totalAdvance).clamp(0.0, double.infinity);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'post': post,
    'salary': salary,
    'joining_date': joiningDate,
    'advances': advances.map((a) => a.toJson()).toList(),
  };

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    List<StaffAdvance> advList = [];
    if (json['advances'] is List) {
      advList = (json['advances'] as List)
          .map((a) => StaffAdvance.fromJson(a as Map<String, dynamic>))
          .toList();
    }
    return StaffMember(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      post: json['post']?.toString() ?? '',
      salary: (json['salary'] as num?)?.toDouble() ?? 0.0,
      joiningDate: json['joining_date']?.toString() ?? '',
      advances: advList,
    );
  }
}

class RedeemLog {
  final String id;
  final String dealId;
  final String dealTitle;
  final String dealCode;
  final String studentName;
  final DateTime timestamp;

  const RedeemLog({
    required this.id,
    required this.dealId,
    required this.dealTitle,
    required this.dealCode,
    required this.studentName,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'deal_id': dealId,
    'deal_title': dealTitle,
    'deal_code': dealCode,
    'student_name': studentName,
    'timestamp': timestamp.toIso8601String(),
  };

  factory RedeemLog.fromJson(Map<String, dynamic> json) => RedeemLog(
    id: json['id']?.toString() ?? '',
    dealId: json['deal_id']?.toString() ?? '',
    dealTitle: json['deal_title']?.toString() ?? '',
    dealCode: json['deal_code']?.toString() ?? '',
    studentName: json['student_name']?.toString() ?? 'Student',
    timestamp: json['timestamp'] != null
        ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
        : DateTime.now(),
  );
}
