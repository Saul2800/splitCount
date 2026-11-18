import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import '../core/constants/api_constants.dart';
import '../data/local/app_database.dart';

class SyncService {
  final Dio _dio;
  final AppDatabase _db;

  SyncService(this._db)
      : _dio = Dio(
          BaseOptions(
            connectTimeout: ApiConstants.connectTimeout,
            receiveTimeout: ApiConstants.receiveTimeout,
          ),
        );

  /// Pulls remote changes from Cloudflare D1 and updates local Drift database.
  Future<bool> pullGroupChanges({
    required String groupId,
    required String groupToken,
    int sinceTimestamp = 0,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.syncPullEndpoint,
        options: Options(
          headers: {'X-Group-Token': groupToken},
        ),
        data: {
          'group_id': groupId,
          'since_timestamp': sinceTimestamp,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'];
        if (data == null) return false;

        final rawExpenses = (data['expenses'] as List<dynamic>?) ?? [];
        final rawMembers = (data['members'] as List<dynamic>?) ?? [];
        final rawSettlements = (data['settlements'] as List<dynamic>?) ?? [];

        // Save incoming members
        for (final m in rawMembers) {
          await _db.into(_db.groupMembers).insertOnConflictUpdate(
                GroupMembersCompanion(
                  id: Value(m['id']),
                  groupId: Value(m['group_id']),
                  name: Value(m['name']),
                  avatarUrl: Value(m['avatar_url']),
                  isClaimed: Value(m['is_claimed'] == 1),
                  createdAt: Value(m['created_at']),
                  updatedAt: Value(m['updated_at']),
                  isDeleted: Value(m['is_deleted'] == 1),
                ),
              );
        }

        // Save incoming expenses
        for (final e in rawExpenses) {
          await _db.into(_db.expenses).insertOnConflictUpdate(
                ExpensesCompanion(
                  id: Value(e['id']),
                  groupId: Value(e['group_id']),
                  title: Value(e['title']),
                  amount: Value((e['amount'] as num).toDouble()),
                  currency: Value(e['currency'] ?? 'USD'),
                  categoryId: Value(e['category_id']),
                  splitType: Value(e['split_type']),
                  expenseDate: Value(e['expense_date']),
                  notes: Value(e['notes']),
                  createdBy: Value(e['created_by']),
                  createdAt: Value(e['created_at']),
                  updatedAt: Value(e['updated_at']),
                  version: Value(e['version'] ?? 1),
                  isDeleted: Value(e['is_deleted'] == 1),
                ),
              );
        }

        // Save incoming settlements
        for (final s in rawSettlements) {
          await _db.into(_db.settlements).insertOnConflictUpdate(
                SettlementsCompanion(
                  id: Value(s['id']),
                  groupId: Value(s['group_id']),
                  payerId: Value(s['payer_id']),
                  recipientId: Value(s['recipient_id']),
                  amount: Value((s['amount'] as num).toDouble()),
                  settlementDate: Value(s['settlement_date']),
                  notes: Value(s['notes']),
                  createdAt: Value(s['created_at']),
                  updatedAt: Value(s['updated_at']),
                  isDeleted: Value(s['is_deleted'] == 1),
                ),
              );
        }

        return true;
      }
    } catch (_) {
      // Offline or network error: fail gracefully without crashing
      return false;
    }
    return false;
  }
}
