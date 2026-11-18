import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Groups,
  GroupMembers,
  Categories,
  Expenses,
  ExpensePayers,
  ExpenseSplits,
  Settlements,
  AuditLogs,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Schema migrations will be placed here using additive ALTER TABLE
        },
        beforeOpen: (details) async {
          // Enable SQLite Foreign Keys
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'splitcount_db',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }

  // --- Group Queries ---
  Stream<List<Group>> watchAllGroups() {
    return (select(groups)..where((tbl) => tbl.isDeleted.equals(false))).watch();
  }

  Future<Group?> getGroupById(String id) {
    return (select(groups)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<Group?> getGroupByToken(String token) {
    return (select(groups)..where((tbl) => tbl.groupToken.equals(token))).getSingleOrNull();
  }

  Future<int> insertGroup(GroupsCompanion group) => into(groups).insert(group);
  Future<bool> updateGroup(GroupsCompanion group) => update(groups).replace(group);

  // --- Members Queries ---
  Stream<List<GroupMember>> watchMembersForGroup(String groupId) {
    return (select(groupMembers)
          ..where((tbl) => tbl.groupId.equals(groupId) & tbl.isDeleted.equals(false)))
        .watch();
  }

  Future<List<GroupMember>> getMembersForGroup(String groupId) {
    return (select(groupMembers)
          ..where((tbl) => tbl.groupId.equals(groupId) & tbl.isDeleted.equals(false)))
        .get();
  }

  Future<int> insertMember(GroupMembersCompanion member) => into(groupMembers).insert(member);

  // --- Expenses Queries ---
  Stream<List<Expense>> watchExpensesForGroup(String groupId) {
    return (select(expenses)
          ..where((tbl) => tbl.groupId.equals(groupId) & tbl.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.expenseDate)]))
        .watch();
  }

  Future<List<Expense>> getExpensesForGroup(String groupId) {
    return (select(expenses)
          ..where((tbl) => tbl.groupId.equals(groupId) & tbl.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.expenseDate)]))
        .get();
  }

  Future<int> insertExpense(ExpensesCompanion expense) => into(expenses).insert(expense);
  Future<bool> updateExpense(ExpensesCompanion expense) => update(expenses).replace(expense);

  // --- Expense Payers & Splits Queries ---
  Future<List<ExpensePayer>> getPayersForExpense(String expenseId) {
    return (select(expensePayers)..where((tbl) => tbl.expenseId.equals(expenseId))).get();
  }

  Future<List<ExpenseSplit>> getSplitsForExpense(String expenseId) {
    return (select(expenseSplits)..where((tbl) => tbl.expenseId.equals(expenseId))).get();
  }

  Future<void> saveExpenseWithDetails({
    required ExpensesCompanion expense,
    required List<ExpensePayersCompanion> payers,
    required List<ExpenseSplitsCompanion> splits,
  }) async {
    await transaction(() async {
      await into(expenses).insertOnConflictUpdate(expense);
      // Remove old payers/splits if updating
      await (delete(expensePayers)..where((tbl) => tbl.expenseId.equals(expense.id.value))).go();
      await (delete(expenseSplits)..where((tbl) => tbl.expenseId.equals(expense.id.value))).go();

      for (final p in payers) {
        await into(expensePayers).insert(p);
      }
      for (final s in splits) {
        await into(expenseSplits).insert(s);
      }
    });
  }

  // --- Settlements Queries ---
  Stream<List<Settlement>> watchSettlementsForGroup(String groupId) {
    return (select(settlements)
          ..where((tbl) => tbl.groupId.equals(groupId) & tbl.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.settlementDate)]))
        .watch();
  }

  Future<List<Settlement>> getSettlementsForGroup(String groupId) {
    return (select(settlements)
          ..where((tbl) => tbl.groupId.equals(groupId) & tbl.isDeleted.equals(false)))
        .get();
  }

  Future<int> insertSettlement(SettlementsCompanion settlement) => into(settlements).insert(settlement);

  // --- Audit Logs Queries ---
  Stream<List<AuditLog>> watchAuditLogsForGroup(String groupId) {
    return (select(auditLogs)
          ..where((tbl) => tbl.groupId.equals(groupId))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .watch();
  }

  Future<int> insertAuditLog(AuditLogsCompanion log) => into(auditLogs).insert(log);
}
