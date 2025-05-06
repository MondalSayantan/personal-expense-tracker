import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../services/update_service.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/expense_chart.dart';
import '../widgets/expense_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _timeFilter = 'All';

  @override
  void initState() {
    super.initState();
    // Initialize with MongoDB URL from environment after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initMongoDb();
      _checkForUpdates();
    });
  }
  
  // Check for app updates
  Future<void> _checkForUpdates() async {
    // Wait a moment to ensure the app is fully loaded
    await Future.delayed(const Duration(seconds: 2));
    UpdateService().checkForUpdates(context);
  }

  Future<void> _initMongoDb() async {
    final expenseProvider =
        Provider.of<ExpenseProvider>(context, listen: false);

    // Get MongoDB URL from environment variables
    final mongoUrl = dotenv.env['MONGODB_URI'] ?? '';

    // Handle the case where MongoDB URI is missing
    if (mongoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('MongoDB connection string not found. Check your .env file.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Initialize the database
    await expenseProvider.init(mongoUrl);
  }

  // Show bottom sheet to add or edit expense
  void _showAddExpenseSheet([Expense? expense]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => AddExpenseSheet(
        expense: expense,
        onSave: (newExpense) {
          final expenseProvider = Provider.of<ExpenseProvider>(
            context,
            listen: false,
          );

          if (expense == null) {
            expenseProvider.addExpense(newExpense);
          } else {
            expenseProvider.updateExpense(newExpense);
          }
        },
      ),
    );
  }

  // Get filtered expenses based on time selection
  List<Expense> _getFilteredExpenses(List<Expense> allExpenses) {
    final now = DateTime.now();
    switch (_timeFilter) {
      case 'Today':
        final startOfDay = DateTime(now.year, now.month, now.day);
        return allExpenses.where((e) => e.date.isAfter(startOfDay)).toList();

      case 'This Week':
        final startOfWeek = now.subtract(
          Duration(days: now.weekday - 1),
        );
        final startOfDay = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day,
        );
        return allExpenses.where((e) => e.date.isAfter(startOfDay)).toList();

      case 'This Month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        return allExpenses.where((e) => e.date.isAfter(startOfMonth)).toList();

      default:
        return allExpenses;
    }
  }

  // Get expenses by category for the filtered period
  Map<String, double> _getCategoryData(List<Expense> filteredExpenses) {
    final categoryMap = <String, double>{};

    for (final expense in filteredExpenses) {
      categoryMap[expense.category] =
          (categoryMap[expense.category] ?? 0) + expense.amount;
    }

    return categoryMap;
  }

  // Calculate total amount for filtered expenses
  double _calculateTotal(List<Expense> filteredExpenses) {
    return filteredExpenses.fold(
      0,
      (sum, expense) => sum + expense.amount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat =
        NumberFormat.currency(symbol: '₹', decimalDigits: 2, locale: 'hi_IN');

    // MongoDB is now initialized directly through environment variables

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: [
          // Sync button
          Consumer<ExpenseProvider>(
            builder: (context, expenseProvider, _) {
              // Show different icon based on sync status
              IconData iconData;
              Color? iconColor;

              switch (expenseProvider.syncStatus) {
                case SyncStatus.synced:
                  iconData = Icons.cloud_done;
                  iconColor = Colors.green;
                  break;
                case SyncStatus.syncing:
                  iconData = Icons.sync;
                  break;
                case SyncStatus.pendingSync:
                  iconData = Icons.cloud_upload;
                  iconColor = Colors.amber;
                  break;
                case SyncStatus.error:
                  iconData = Icons.cloud_off;
                  iconColor = Colors.red;
                  break;
                case SyncStatus.offline:
                  iconData = Icons.signal_wifi_off;
                  break;
              }

              return IconButton(
                icon: Icon(iconData, color: iconColor),
                onPressed: expenseProvider.syncStatus != SyncStatus.syncing
                    ? expenseProvider.syncWithMongoDB
                    : null,
                tooltip: 'Sync with MongoDB',
              );
            },
          ),

          // Theme toggle
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return IconButton(
                icon: Icon(
                  themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                ),
                onPressed: themeProvider.toggleTheme,
                tooltip: 'Toggle theme',
              );
            },
          ),
        ],
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, expenseProvider, _) {
          if (expenseProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final filteredExpenses =
              _getFilteredExpenses(expenseProvider.expenses);
          final categoryData = _getCategoryData(filteredExpenses);
          final total = _calculateTotal(filteredExpenses);

          return Column(
            children: [
              // Time filter
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: ['All', 'Today', 'This Week', 'This Month']
                      .map((filter) => Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ChoiceChip(
                              label: Text(filter),
                              selected: _timeFilter == filter,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _timeFilter = filter;
                                  });
                                }
                              },
                            ),
                          ))
                      .toList(),
                ),
              ),

              // Total amount
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total $_timeFilter Expenses',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currencyFormat.format(total),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.account_balance_wallet,
                      size: 40,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ],
                ),
              ),

              // Chart
              if (filteredExpenses.isNotEmpty)
                ExpenseChart(
                  categoryData: categoryData,
                  total: total,
                ),

              // Expense list
              Expanded(
                child: filteredExpenses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 70,
                              color: theme.colorScheme.primary.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No expenses found',
                              style: theme.textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the + button to add a new expense',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredExpenses.length,
                        itemBuilder: (ctx, index) {
                          final expense = filteredExpenses[index];
                          return ExpenseTile(
                            expense: expense,
                            onDelete: () {
                              expenseProvider.deleteExpense(expense.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Expense deleted'),
                                  action: SnackBarAction(
                                    label: 'Undo',
                                    onPressed: () {
                                      expenseProvider.addExpense(expense);
                                    },
                                  ),
                                ),
                              );
                            },
                            onEdit: () => _showAddExpenseSheet(expense),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExpenseSheet(),
        tooltip: 'Add Expense',
        child: const Icon(Icons.add),
      ),
    );
  }
}
