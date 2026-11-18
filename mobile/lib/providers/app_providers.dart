import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local/app_database.dart';
import '../services/sync_service.dart';
import '../core/utils/debt_simplifier.dart';

// Database Provider
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// Sync Service Provider
final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncService(db);
});

// Active Group Provider
final activeGroupIdProvider = StateProvider<String?>((ref) => null);

// All Groups Stream
final allGroupsStreamProvider = StreamProvider<List<Group>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllGroups();
});

// Active Group Stream
final activeGroupProvider = Provider<Group?>((ref) {
  final groups = ref.watch(allGroupsStreamProvider).value ?? [];
  final activeId = ref.watch(activeGroupIdProvider);
  if (activeId == null) return groups.isNotEmpty ? groups.first : null;
  return groups.firstWhere((g) => g.id == activeId, orElse: () => groups.first);
});

// Active Group Members Stream
final groupMembersProvider = StreamProvider<List<GroupMember>>((ref) {
  final group = ref.watch(activeGroupProvider);
  if (group == null) return const Stream.empty();
  final db = ref.watch(databaseProvider);
  return db.watchMembersForGroup(group.id);
});

// Active Group Expenses Stream
final groupExpensesProvider = StreamProvider<List<Expense>>((ref) {
  final group = ref.watch(activeGroupProvider);
  if (group == null) return const Stream.empty();
  final db = ref.watch(databaseProvider);
  return db.watchExpensesForGroup(group.id);
});

// Active Group Settlements Stream
final groupSettlementsProvider = StreamProvider<List<Settlement>>((ref) {
  final group = ref.watch(activeGroupProvider);
  if (group == null) return const Stream.empty();
  final db = ref.watch(databaseProvider);
  return db.watchSettlementsForGroup(group.id);
});

// Net Balances Provider
final groupNetBalancesProvider = FutureProvider<Map<String, double>>((ref) async {
  final group = ref.watch(activeGroupProvider);
  if (group == null) return {};

  final db = ref.watch(databaseProvider);
  final members = ref.watch(groupMembersProvider).value ?? [];
  final expenses = ref.watch(groupExpensesProvider).value ?? [];
  final settlements = ref.watch(groupSettlementsProvider).value ?? [];

  final Map<String, double> balances = {for (final m in members) m.id: 0.0};

  for (final exp in expenses) {
    final payers = await db.getPayersForExpense(exp.id);
    final splits = await db.getSplitsForExpense(exp.id);

    // Payers get credited (+)
    for (final p in payers) {
      balances[p.memberId] = (balances[p.memberId] ?? 0.0) + p.amountPaid;
    }

    // Split members get debited (-)
    for (final s in splits) {
      balances[s.memberId] = (balances[s.memberId] ?? 0.0) - s.amountOwed;
    }
  }

  // Factor in settlements
  for (final s in settlements) {
    // Payer paid money -> balance increases (+)
    balances[s.payerId] = (balances[s.payerId] ?? 0.0) + s.amount;
    // Recipient received money -> balance decreases (-)
    balances[s.recipientId] = (balances[s.recipientId] ?? 0.0) - s.amount;
  }

  return balances;
});

// Simplified Debts Provider
final simplifiedDebtsProvider = FutureProvider<List<DebtTransfer>>((ref) async {
  final netBalances = await ref.watch(groupNetBalancesProvider.future);
  return DebtSimplifier.simplifyDebts(netBalances);
});
