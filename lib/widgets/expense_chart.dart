import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';

class ExpenseChart extends StatelessWidget {
  final Map<String, double> categoryData;
  final double total;

  const ExpenseChart({
    super.key,
    required this.categoryData,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // If no data, show placeholder
    if (categoryData.isEmpty || total <= 0) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No expense data to display',
            style: theme.textTheme.bodyLarge,
          ),
        ),
      );
    }

    // Get color for each category
    List<Color> getColors() {
      return [
        theme.colorScheme.primary,
        theme.colorScheme.secondary,
        theme.colorScheme.tertiary,
        theme.colorScheme.error,
        theme.colorScheme.primaryContainer,
        theme.colorScheme.secondaryContainer,
        theme.colorScheme.tertiaryContainer,
        theme.colorScheme.errorContainer,
      ];
    }

    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          'Spending by Category',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              sections: _createSections(getColors()),
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  // Optional: Add touch interaction
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildLegend(context, getColors()),
      ],
    );
  }

  // Create the pie sections based on category data
  List<PieChartSectionData> _createSections(List<Color> colors) {
    final sections = <PieChartSectionData>[];
    int colorIndex = 0;
    
    categoryData.forEach((category, amount) {
      final percentage = (amount / total) * 100;
      final color = colors[colorIndex % colors.length];
      
      sections.add(
        PieChartSectionData(
          color: color,
          value: amount,
          title: '${percentage.toStringAsFixed(1)}%',
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      
      colorIndex++;
    });
    
    return sections;
  }

  // Build the legend
  Widget _buildLegend(BuildContext context, List<Color> colors) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'hi_IN');
    
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: categoryData.entries.map((entry) {
        final index = categoryData.keys.toList().indexOf(entry.key);
        final color = colors[index % colors.length];
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${entry.key.displayName}: ${currencyFormat.format(entry.value)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        );
      }).toList(),
    );
  }
}
