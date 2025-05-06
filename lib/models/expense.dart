import 'package:uuid/uuid.dart';

// TODO: Add @HiveType and @HiveField annotations when generating adapters
class Expense {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String category;
  final String paymentMethod;
  final String? description; // Optional description field
  bool synced;

  Expense({
    String? id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    required this.paymentMethod,
    this.description, // Optional description
    this.synced = false,
  }) : id = id ?? const Uuid().v4();

  // Copy with method for creating modified copies
  Expense copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? date,
    String? category,
    String? paymentMethod,
    String? description,
    bool? synced,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      description: description ?? this.description,
      synced: synced ?? this.synced,
    );
  }

  // Convert to JSON for MongoDB
  Map<String, dynamic> toJson() {
    final json = {
      '_id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'paymentMethod': paymentMethod,
      'synced': synced,
    };
    
    // Add description only if it's not null and not empty
    if (description != null && description!.isNotEmpty) {
      json['description'] = description as String;
    }
    
    return json;
  }

  // Create from JSON (from MongoDB)
  factory Expense.fromJson(Map<String, dynamic> json) {
    // Parse description safely
    String? descriptionValue;
    if (json.containsKey('description') && json['description'] != null) {
      descriptionValue = json['description'].toString();
    }
    
    return Expense(
      id: json['_id'],
      title: json['title'],
      amount: json['amount'] is int
          ? (json['amount'] as int).toDouble()
          : json['amount'],
      date: DateTime.parse(json['date']),
      category: json['category'],
      description: descriptionValue,
      paymentMethod:
          json['paymentMethod'] ?? 'cash', // Default to cash for older entries
      synced: json['synced'] ?? true,
    );
  }

  // We'll need to generate the Hive adapter with:
  // flutter packages pub run build_runner build
}

// Available expense categories
enum ExpenseCategory {
  food,
  groceries,
  transportation,
  flight,
  entertainment,
  restaurant,
  streetFood,
  utilities,
  shopping,
  health,
  education,
  other,
}

// Available payment methods
enum PaymentMethod {
  cash,
  upi,
  amazonPay,
  amex, // American Express
  tataNeuInfinity, // Tata Neu Infinity credit card
  swiggy, // Swiggy credit card
}

// Extension to get display strings and icons for categories
extension ExpenseCategoryExtension on String {
  static const categoryMap = {
    'food': 'Food Delivery',
    'transportation': 'Transportation',
    'streetFood': 'Street Food',
    'groceries': 'Groceries & Vegetables',
    'entertainment': 'Entertainment',
    'restaurant': 'Restaurant',
    'utilities': 'Bills & Utilities',
    'shopping': 'Shopping',
    'health': 'Health & Medicines',
    'flight': 'Flight',
    'education': 'Education',
    'other': 'Other',
  };

  String get displayName {
    // For regular categories
    if (categoryMap.containsKey(this)) {
      return categoryMap[this]!;
    }

    // For 'other - custom' format
    if (this.startsWith('other - ')) {
      String customCategory = this.substring('other - '.length);
      return 'Other: $customCategory';
    }

    return 'Unknown';
  }
}

// Extension for payment method display names
extension PaymentMethodExtension on String {
  static const paymentMap = {
    'cash': 'Cash',
    'upi': 'UPI',
    'amazonPay': 'Amazon Pay',
    'amex': 'AMEX',
    'tataNeuInfinity': 'Tata Neu Infinity',
    'swiggy': 'Swiggy Card',
  };

  String get paymentDisplayName => paymentMap[this] ?? 'Unknown';
}
