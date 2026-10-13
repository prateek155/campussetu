class MoneyTransaction {
  final String id;
  final String type; // 'expense' or 'income'
  final double amount;
  final String title;
  final String category;
  final String date; // YYYY-MM-DD
  final String method; // 'UPI', 'Cash', 'Debit card', 'Credit card', 'Bank transfer', 'Other'
  final String note;

  MoneyTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.title,
    required this.category,
    required this.date,
    required this.method,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'amount': amount,
    'title': title,
    'category': category,
    'date': date,
    'method': method,
    'note': note,
  };

  factory MoneyTransaction.fromJson(Map<String, dynamic> json) => MoneyTransaction(
    id: json['id']?.toString() ?? '',
    type: json['type']?.toString() ?? 'expense',
    amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    title: json['title']?.toString() ?? '',
    category: json['category']?.toString() ?? 'Food',
    date: json['date']?.toString() ?? '',
    method: json['method']?.toString() ?? 'UPI',
    note: json['note']?.toString() ?? '',
  );
}

class UdhaarLoan {
  final String id;
  final String friend;
  final String direction; // 'lent' or 'borrowed'
  final double amount;
  final double remaining;
  final String date;
  final String note;

  UdhaarLoan({
    required this.id,
    required this.friend,
    required this.direction,
    required this.amount,
    required this.remaining,
    required this.date,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'friend': friend,
    'direction': direction,
    'amount': amount,
    'remaining': remaining,
    'date': date,
    'note': note,
  };

  factory UdhaarLoan.fromJson(Map<String, dynamic> json) => UdhaarLoan(
    id: json['id']?.toString() ?? '',
    friend: json['friend']?.toString() ?? '',
    direction: json['direction']?.toString() ?? 'lent',
    amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    remaining: (json['remaining'] as num?)?.toDouble() ?? 0.0,
    date: json['date']?.toString() ?? '',
    note: json['note']?.toString() ?? '',
  );

  UdhaarLoan copyWith({double? remaining}) => UdhaarLoan(
    id: id,
    friend: friend,
    direction: direction,
    amount: amount,
    remaining: remaining ?? this.remaining,
    date: date,
    note: note,
  );
}

class SplitGroup {
  final String id;
  final String name;
  final List<String> members;

  SplitGroup({
    required this.id,
    required this.name,
    required this.members,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'members': members,
  };

  factory SplitGroup.fromJson(Map<String, dynamic> json) => SplitGroup(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    members: (json['members'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
  );
}

class SplitBill {
  final String id;
  final String groupId;
  final String title;
  final double amount;
  final String payer;
  final String mode; // 'Equal' or 'Custom'
  final String date;
  final Map<String, double>? shares;

  SplitBill({
    required this.id,
    required this.groupId,
    required this.title,
    required this.amount,
    required this.payer,
    required this.mode,
    required this.date,
    this.shares,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'groupId': groupId,
    'title': title,
    'amount': amount,
    'payer': payer,
    'mode': mode,
    'date': date,
    if (shares != null) 'shares': shares,
  };

  factory SplitBill.fromJson(Map<String, dynamic> json) {
    Map<String, double>? s;
    if (json['shares'] is Map) {
      s = (json['shares'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
    }
    return SplitBill(
      id: json['id']?.toString() ?? '',
      groupId: json['groupId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      payer: json['payer']?.toString() ?? '',
      mode: json['mode']?.toString() ?? 'Equal',
      date: json['date']?.toString() ?? '',
      shares: s,
    );
  }
}
