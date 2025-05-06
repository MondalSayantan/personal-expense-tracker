import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../services/database_service.dart';

class ExpenseProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  List<Expense> _expenses = [];
  SyncStatus _syncStatus = SyncStatus.offline;
  bool _isLoading = false;
  bool _isInitialized = false;

  ExpenseProvider() {
    // Don't load or listen until explicitly initialized
  }

  // Getters
  List<Expense> get expenses => _expenses;
  SyncStatus get syncStatus => _syncStatus;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  // Initialize with MongoDB URL
  Future<void> init(String mongoUrl) async {
    if (_isInitialized) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      await _db.init(mongoUrl: mongoUrl);
      await _loadExpenses();
      _listenToSyncStatus();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing database: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Listen to sync status changes
  void _listenToSyncStatus() {
    _db.syncStatus.listen((status) {
      _syncStatus = status;
      notifyListeners();
    });
  }

  // Load expenses from local storage
  Future<void> _loadExpenses() async {
    _expenses = _db.getAllExpenses();
    _expenses.sort((a, b) => b.date.compareTo(a.date)); // Sort by date, newest first
    notifyListeners();
  }

  // Add a new expense
  Future<void> addExpense(Expense expense) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _db.addExpense(expense);
      await _loadExpenses();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update an expense
  Future<void> updateExpense(Expense expense) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _db.updateExpense(expense);
      await _loadExpenses();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete an expense
  Future<void> deleteExpense(String id) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _db.deleteExpense(id);
      await _loadExpenses();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Manually sync with MongoDB
  Future<void> syncWithMongoDB() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _db.syncWithMongoDB();
      await _loadExpenses();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get total spending for a time period
  double getTotalForPeriod(DateTime start, DateTime end) {
    return _expenses
        .where((e) => e.date.isAfter(start) && e.date.isBefore(end))
        .fold(0, (sum, expense) => sum + expense.amount);
  }

  // Get expenses by category
  Map<String, double> getExpensesByCategory() {
    final categoryTotals = <String, double>{};
    
    for (final expense in _expenses) {
      categoryTotals[expense.category] = 
          (categoryTotals[expense.category] ?? 0) + expense.amount;
    }
    
    return categoryTotals;
  }

  // Cleanup
  void dispose() {
    _db.dispose();
    super.dispose();
  }
}
