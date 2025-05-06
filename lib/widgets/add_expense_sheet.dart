import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';

class AddExpenseSheet extends StatefulWidget {
  final Expense? expense;
  final Function(Expense) onSave;

  const AddExpenseSheet({
    super.key,
    this.expense,
    required this.onSave,
  });

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _customCategoryController = TextEditingController();
  final _descriptionController = TextEditingController(); // For optional description
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'food';
  String _selectedPaymentMethod = 'cash';
  
  @override
  void initState() {
    super.initState();
    // If editing an existing expense, pre-fill the form
    if (widget.expense != null) {
      _titleController.text = widget.expense!.title;
      _amountController.text = widget.expense!.amount.toString();
      _selectedDate = widget.expense!.date;
      _selectedCategory = widget.expense!.category;
      _selectedPaymentMethod = widget.expense!.paymentMethod;
      if (widget.expense!.description != null) {
        _descriptionController.text = widget.expense!.description!;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _customCategoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Show date picker
  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    
    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  // Save the expense
  void _saveExpense() {
    if (_formKey.currentState!.validate()) {
      // Process category (for 'other' with custom text)
      String category = _selectedCategory;
      if (_selectedCategory == 'other' && _customCategoryController.text.trim().isNotEmpty) {
        category = 'other - ${_customCategoryController.text.trim()}';
      }
      
      // Get description (if provided)
      String? description = _descriptionController.text.trim().isNotEmpty 
          ? _descriptionController.text.trim() 
          : null;
      
      final expense = Expense(
        id: widget.expense?.id,  // If null, a new UUID will be generated
        title: _titleController.text.trim(),
        amount: double.parse(_amountController.text),
        date: _selectedDate,
        category: category,
        paymentMethod: _selectedPaymentMethod,
        description: description, // Optional description field
        synced: false,  // New or updated expenses need to be synced
      );
      
      widget.onSave(expense);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormatter = DateFormat('MMM dd, yyyy');
    
    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.expense == null ? 'Add New Expense' : 'Edit Expense',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Title field
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                prefixIcon: Icon(Icons.title),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Amount field
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                try {
                  final amount = double.parse(value);
                  if (amount <= 0) {
                    return 'Amount must be greater than zero';
                  }
                } catch (e) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Date picker
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(dateFormatter.format(_selectedDate)),
              ),
            ),
            const SizedBox(height: 16),
            
            // Category dropdown
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category),
              ),
              value: _selectedCategory,
              items: [
                ...ExpenseCategoryExtension.categoryMap.keys.toList(),
                // Only add 'other' if it's not already in the map
                if (!ExpenseCategoryExtension.categoryMap.containsKey('other')) 'other',
              ].map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                  });
                }
              },
            ),
            
            // Custom category field (only shown if "Other" is selected)
            if (_selectedCategory == 'other') ...[  
              const SizedBox(height: 16),
              TextFormField(
                controller: _customCategoryController,
                decoration: const InputDecoration(
                  labelText: 'Specify Category',
                  helperText: 'Enter your custom category name',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (_selectedCategory == 'other' && (value == null || value.trim().isEmpty)) {
                    return 'Please specify the category';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 16),
            
            // Payment method dropdown
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Payment Method',
                prefixIcon: Icon(Icons.payment),
              ),
              value: _selectedPaymentMethod,
              items: [
                'cash',
                'upi',
                'amazonPay',
                'amex',
                'tataNeuInfinity',
                'swiggy',
              ].map((method) {
                return DropdownMenuItem(
                  value: method,
                  child: Text(method.paymentDisplayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPaymentMethod = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            
            // Optional description field
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                helperText: 'Add additional details about this expense',
                prefixIcon: Icon(Icons.description),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            
            // Save button
            ElevatedButton(
              onPressed: _saveExpense,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                widget.expense == null ? 'Add Expense' : 'Update Expense',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
