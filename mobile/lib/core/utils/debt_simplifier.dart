class DebtTransfer {
  final String fromMemberId;
  final String toMemberId;
  final double amount;

  DebtTransfer({
    required this.fromMemberId,
    required this.toMemberId,
    required this.amount,
  });
}

class DebtSimplifier {
  /// Simplifies group debts into the minimum number of direct transactions
  /// using the greedy Min-Cash-Flow algorithm.
  static List<DebtTransfer> simplifyDebts(Map<String, double> netBalances) {
    final List<DebtTransfer> transfers = [];

    // Separate into debtors (< 0) and creditors (> 0)
    final Map<String, double> debtors = {};
    final Map<String, double> creditors = {};

    netBalances.forEach((memberId, balance) {
      final rounded = double.parse(balance.toStringAsFixed(2));
      if (rounded < -0.01) {
        debtors[memberId] = -rounded; // Store as positive amount owed
      } else if (rounded > 0.01) {
        creditors[memberId] = rounded;
      }
    });

    final debtorKeys = debtors.keys.toList();
    final creditorKeys = creditors.keys.toList();

    int dIdx = 0;
    int cIdx = 0;

    while (dIdx < debtorKeys.length && cIdx < creditorKeys.length) {
      final debtorId = debtorKeys[dIdx];
      final creditorId = creditorKeys[cIdx];

      final owed = debtors[debtorId]!;
      final credit = creditors[creditorId]!;

      final minAmount = owed < credit ? owed : credit;

      if (minAmount > 0.01) {
        transfers.add(
          DebtTransfer(
            fromMemberId: debtorId,
            toMemberId: creditorId,
            amount: double.parse(minAmount.toStringAsFixed(2)),
          ),
        );
      }

      debtors[debtorId] = owed - minAmount;
      creditors[creditorId] = credit - minAmount;

      if (debtors[debtorId]! <= 0.01) dIdx++;
      if (creditors[creditorId]! <= 0.01) cIdx++;
    }

    return transfers;
  }
}
