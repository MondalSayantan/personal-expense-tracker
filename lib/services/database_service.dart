import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import '../models/expense.dart';
import '../utils/app_logger.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  mongo.Db? _db;
  Box<Expense>? _expensesBox;
  final _connectivity = Connectivity();
  StreamSubscription? _connectivitySubscription;
  bool _isOnline = false;
  String? _mongoUrl;

  // Stream controller to broadcast sync status
  final _syncController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatus => _syncController.stream;

  // Initialize database connections
  Future<void> init({required String mongoUrl}) async {
    _mongoUrl = mongoUrl;

    try {
      // Initialize Hive
      await Hive.initFlutter();

      // Register the adapter if not already registered
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(ExpenseAdapter());
      }

      // Open the expenses box
      _expensesBox = await Hive.openBox<Expense>('expenses');
      AppLogger.log(
          'Hive initialized successfully with ${_expensesBox?.length ?? 0} expenses');

      // Check initial connectivity
      _checkConnectivity();

      // Listen for connectivity changes
      _connectivitySubscription =
          _connectivity.onConnectivityChanged.listen((_) {
        _checkConnectivity();
      });
    } catch (e) {
      AppLogger.log('Error initializing database: $e');
      rethrow;
    }
  }

  // Check and update connectivity status
  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;

      // If we just came online, try to sync
      if (!wasOnline && _isOnline) {
        _syncController.add(SyncStatus.syncing);
        await syncWithMongoDB();
        _syncController.add(SyncStatus.synced);
      } else if (!_isOnline) {
        _syncController.add(SyncStatus.offline);
      }
    } catch (e) {
      _isOnline = false;
      _syncController.add(SyncStatus.error);
      AppLogger.log('Connectivity check error: $e');
    }
  }

  // Connect to MongoDB
  Future<void> _connectToMongoDB() async {
    if (_db != null) return;

    try {
      _db = await mongo.Db.create(_mongoUrl!);
      await _db!.open();
      AppLogger.log('MongoDB connected');
    } catch (e) {
      AppLogger.log('MongoDB connection error: $e');
      _syncController.add(SyncStatus.error);
      rethrow;
    }
  }

  // Add expense, tries MongoDB first if online, saves to Hive regardless
  Future<void> addExpense(Expense expense) async {
    try {
      if (_isOnline) {
        await _connectToMongoDB();
        await _db!.collection('expenses').insert(expense.toJson());
        expense = expense.copyWith(synced: true);
      }

      await _expensesBox!.put(expense.id, expense);
      _syncController
          .add(_isOnline ? SyncStatus.synced : SyncStatus.pendingSync);
    } catch (e) {
      AppLogger.log('Error adding expense: $e');
      // Save to local even if MongoDB fails
      expense = expense.copyWith(synced: false);
      await _expensesBox!.put(expense.id, expense);
      _syncController.add(SyncStatus.pendingSync);
    }
  }

  // Update expense
  Future<void> updateExpense(Expense expense) async {
    try {
      if (_isOnline) {
        await _connectToMongoDB();
        await _db!.collection('expenses').update(
              mongo.where.eq('_id', expense.id),
              expense.toJson(),
            );
        expense = expense.copyWith(synced: true);
      } else {
        expense = expense.copyWith(synced: false);
      }

      await _expensesBox!.put(expense.id, expense);
      _syncController
          .add(_isOnline ? SyncStatus.synced : SyncStatus.pendingSync);
    } catch (e) {
      AppLogger.log('Error updating expense: $e');
      expense = expense.copyWith(synced: false);
      await _expensesBox!.put(expense.id, expense);
      _syncController.add(SyncStatus.pendingSync);
    }
  }

  // Delete expense
  Future<void> deleteExpense(String id) async {
    AppLogger.log('Attempting to delete expense with ID: $id');

    if (_expensesBox == null) {
      AppLogger.log('Error: Expense box is not initialized');
      return;
    }

    try {
      // Log existing expenses before deletion
      AppLogger.log('Current expenses: ${_expensesBox!.length}');
      AppLogger.log('Expense exists in box: ${_expensesBox!.containsKey(id)}');

      // Try to delete from MongoDB if online
      if (_isOnline) {
        await _connectToMongoDB();
        await _db!.collection('expenses').remove(mongo.where.eq('_id', id));
        AppLogger.log('Deleted from MongoDB');
      }

      // Delete from local storage
      await _expensesBox!.delete(id);
      AppLogger.log('Deleted from Hive storage');

      // Log remaining expenses after deletion
      AppLogger.log('Remaining expenses: ${_expensesBox!.length}');

      _syncController
          .add(_isOnline ? SyncStatus.synced : SyncStatus.pendingSync);
    } catch (e) {
      AppLogger.log('Error deleting expense: $e');
      // Mark for deletion later if MongoDB fails
      if (_expensesBox!.containsKey(id)) {
        final expense = _expensesBox!.get(id)!.copyWith(synced: false);
        await _expensesBox!.put(id, expense);
        AppLogger.log('Marked expense for later deletion');
      }
      _syncController.add(SyncStatus.pendingSync);
    }
  }

  // Get all expenses (from Hive)
  List<Expense> getAllExpenses() {
    return _expensesBox!.values.toList();
  }

  // Get expenses for a specific time range
  List<Expense> getExpensesForRange(DateTime start, DateTime end) {
    return _expensesBox!.values
        .where((e) => e.date.isAfter(start) && e.date.isBefore(end))
        .toList();
  }

  // Manually trigger sync with MongoDB
  Future<void> syncWithMongoDB() async {
    if (!_isOnline) {
      _syncController.add(SyncStatus.offline);
      return;
    }

    _syncController.add(SyncStatus.syncing);

    try {
      await _connectToMongoDB();

      // Find all expenses that need to be synced
      final unsynced = _expensesBox!.values.where((e) => !e.synced).toList();

      for (final expense in unsynced) {
        // Check if expense exists in MongoDB
        final existsInMongo = await _db!
                .collection('expenses')
                .findOne(mongo.where.eq('_id', expense.id)) !=
            null;

        if (existsInMongo) {
          await _db!.collection('expenses').update(
                mongo.where.eq('_id', expense.id),
                expense.toJson(),
              );
        } else {
          await _db!.collection('expenses').insert(expense.toJson());
        }

        // Mark as synced and update local storage
        await _expensesBox!.put(
          expense.id,
          expense.copyWith(synced: true),
        );
      }

      // Check for expenses in MongoDB that aren't in local
      final mongoExpenses = await _db!.collection('expenses').find().toList();
      for (final docJson in mongoExpenses) {
        final mongoExpense = Expense.fromJson(docJson);
        if (!_expensesBox!.containsKey(mongoExpense.id)) {
          await _expensesBox!.put(mongoExpense.id, mongoExpense);
        }
      }

      _syncController.add(SyncStatus.synced);
    } catch (e) {
      AppLogger.log('Sync error: $e');
      _syncController.add(SyncStatus.error);
    }
  }

  // Close all connections
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    await _syncController.close();
    await _db?.close();
    await _expensesBox?.close();
  }
}

// Status for sync operations
enum SyncStatus {
  synced,
  syncing,
  pendingSync,
  offline,
  error,
}

// This adapter must be generated:
// flutter packages pub run build_runner build
class ExpenseAdapter extends TypeAdapter<Expense> {
  @override
  final int typeId = 0;

  @override
  Expense read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Expense(
      id: fields[0] as String,
      title: fields[1] as String,
      amount: fields[2] as double,
      date: fields[3] as DateTime,
      category: fields[4] as String,
      paymentMethod: fields[6] != null
          ? fields[6] as String
          : 'cash', // Default to cash for legacy entries
      description: fields[7] as String?, // Optional description
      synced: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Expense obj) {
    writer
      ..writeByte(8) // Updated field count to include description
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.synced)
      ..writeByte(6)
      ..write(obj.paymentMethod)
      ..writeByte(7)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
