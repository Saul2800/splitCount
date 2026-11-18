import '../../data/local/app_database.dart';

class DuplicateMatch {
  final Expense existingExpense;
  final double confidenceScore; // 0.0 to 1.0
  final String reason;

  DuplicateMatch({
    required this.existingExpense,
    required this.confidenceScore,
    required this.reason,
  });
}

class DuplicateDetector {
  static const int timeWindowMs = 2 * 60 * 60 * 1000; // 2 hours

  /// Evaluates an expense against existing expenses to spot duplicates.
  static DuplicateMatch? findPotentialDuplicate({
    required double newAmount,
    required int newDateMs,
    required String newCategoryId,
    required String newTitle,
    required List<Expense> existingExpenses,
    String? excludeExpenseId,
  }) {
    for (final existing in existingExpenses) {
      if (excludeExpenseId != null && existing.id == excludeExpenseId) continue;

      // 1. Check exact or very close amount
      final isAmountMatch = (existing.amount - newAmount).abs() <= 0.01;

      // 2. Check time window (+/- 2 hours)
      final isTimeMatch = (existing.expenseDate - newDateMs).abs() <= timeWindowMs;

      // 3. Category match
      final isCategoryMatch = existing.categoryId == newCategoryId;

      // 4. Title similarity
      final isTitleMatch = existing.title.trim().toLowerCase() == newTitle.trim().toLowerCase();

      if (isAmountMatch && isTimeMatch) {
        double score = 0.7;
        String reason = 'Matching amount within a 2-hour window';

        if (isCategoryMatch) {
          score += 0.15;
          reason += ' and matching category';
        }
        if (isTitleMatch) {
          score += 0.15;
          reason += ' with identical title';
        }

        return DuplicateMatch(
          existingExpense: existing,
          confidenceScore: score,
          reason: reason,
        );
      }
    }

    return null;
  }
}
