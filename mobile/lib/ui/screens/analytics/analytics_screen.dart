import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(activeGroupProvider);
    final expenses = ref.watch(groupExpensesProvider).value ?? [];

    if (group == null || expenses.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Analytics & Charts')),
        body: const Center(child: Text('No expense data available for charts.')),
      );
    }

    final totalSpent = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);

    // Group expenses by category
    final Map<String, double> categoryTotals = {};
    for (final exp in expenses) {
      categoryTotals[exp.categoryId] = (categoryTotals[exp.categoryId] ?? 0.0) + exp.amount;
    }

    final categoryColors = {
      'food': Colors.orangeAccent,
      'transport': Colors.blueAccent,
      'hotel': Colors.purpleAccent,
      'entertainment': Colors.redAccent,
      'supplies': Colors.greenAccent,
    };

    final pieSections = categoryTotals.entries.map((entry) {
      final percentage = totalSpent > 0 ? (entry.value / totalSpent) * 100 : 0.0;
      final color = categoryColors[entry.key] ?? Colors.teal;
      return PieChartSectionData(
        color: color,
        value: entry.value,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 60,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text('${group.name} — Spending Analytics')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Total Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Total Group Expenditure', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      '${group.currency} ${totalSpent.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Donut Chart
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sections: pieSections,
                  centerSpaceRadius: 50,
                  sectionsSpace: 3,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Legend / Breakdown List
            ...categoryTotals.entries.map((entry) {
              final color = categoryColors[entry.key] ?? Colors.teal;
              final percent = totalSpent > 0 ? (entry.value / totalSpent) * 100 : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(entry.key.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Text(
                      '${group.currency} ${entry.value.toStringAsFixed(2)} (${percent.toStringAsFixed(1)}%)',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
