import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/local/app_database.dart';

class CsvExportService {
  static Future<String> generateGroupCsv({
    required Group group,
    required List<Expense> expenses,
    required List<GroupMember> members,
    required List<Settlement> settlements,
  }) async {
    final memberMap = {for (final m in members) m.id: m.name};
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    final List<List<dynamic>> rows = [
      ['Date', 'Title', 'Category', 'Amount', 'Currency', 'Created By', 'Notes'],
    ];

    for (final exp in expenses) {
      final date = DateTime.fromMillisecondsSinceEpoch(exp.expenseDate);
      rows.add([
        dateFormat.format(date),
        exp.title,
        exp.categoryId,
        exp.amount.toStringAsFixed(2),
        exp.currency,
        memberMap[exp.createdBy] ?? 'Unknown',
        exp.notes ?? '',
      ]);
    }

    // Settlements Section
    rows.add([]);
    rows.add(['--- SETTLEMENT PAYMENTS ---']);
    rows.add(['Date', 'Payer', 'Recipient', 'Amount', 'Currency', 'Notes']);
    for (final s in settlements) {
      final date = DateTime.fromMillisecondsSinceEpoch(s.settlementDate);
      rows.add([
        dateFormat.format(date),
        memberMap[s.payerId] ?? 'Unknown',
        memberMap[s.recipientId] ?? 'Unknown',
        s.amount.toStringAsFixed(2),
        group.currency,
        s.notes ?? '',
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/splitcount_${group.name.replaceAll(' ', '_')}.csv');
    await file.writeAsString(csvData);

    return file.path;
  }

  static Future<void> shareGroupCsv({
    required Group group,
    required List<Expense> expenses,
    required List<GroupMember> members,
    required List<Settlement> settlements,
  }) async {
    final filePath = await generateGroupCsv(
      group: group,
      expenses: expenses,
      members: members,
      settlements: settlements,
    );

    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'SplitCount Export: ${group.name}',
    );
  }
}
