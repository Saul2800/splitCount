import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import 'package:qr_flutter/qr_flutter.dart';
import '../../../providers/app_providers.dart';
import '../../../data/local/app_database.dart';
import '../../../services/csv_service.dart';
import '../../../services/receipt_service.dart';
import '../expense/add_expense_screen.dart';
import '../analytics/analytics_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeGroup = ref.watch(activeGroupProvider);
    final allGroups = ref.watch(allGroupsStreamProvider).value ?? [];
    final expenses = ref.watch(groupExpensesProvider).value ?? [];
    final members = ref.watch(groupMembersProvider).value ?? [];
    final settlements = ref.watch(groupSettlementsProvider).value ?? [];
    final simplifiedDebts = ref.watch(simplifiedDebtsProvider).value ?? [];

    if (activeGroup == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('SplitCount')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.group_work_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('No groups yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Create a group or scan an invite code to get started.'),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _showCreateGroupDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Create New Group'),
              ),
            ],
          ),
        ),
      );
    }

    final totalSpent = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);

    return Scaffold(
      appBar: AppBar(
        title: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: activeGroup.id,
            dropdownColor: Theme.of(context).cardColor,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            items: allGroups.map((g) {
              return DropdownMenuItem(
                value: g.id,
                child: Text(g.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              );
            }).toList(),
            onChanged: (id) {
              if (id != null) ref.read(activeGroupIdProvider.notifier).state = id;
            },
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Sync Changes',
            icon: const Icon(Icons.sync),
            onPressed: () async {
              final sync = ref.read(syncServiceProvider);
              final ok = await sync.pullGroupChanges(
                groupId: activeGroup.id,
                groupToken: activeGroup.groupToken,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Sync successful!' : 'Sync completed (offline/no new data)'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Group QR & Invite',
            icon: const Icon(Icons.qr_code),
            onPressed: () => _showGroupQrDialog(context, activeGroup),
          ),
          PopupMenuButton<String>(
            onSelected: (val) async {
              if (val == 'new_group') {
                _showCreateGroupDialog(context);
              } else if (val == 'analytics') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                );
              } else if (val == 'csv') {
                await CsvExportService.shareGroupCsv(
                  group: activeGroup,
                  expenses: expenses,
                  members: members,
                  settlements: settlements,
                );
              } else if (val == 'receipt') {
                await ReceiptTicketService.printOrShareReceipt(
                  group: activeGroup,
                  expenses: expenses,
                  members: members,
                  settlements: settlements,
                  simplifiedDebts: simplifiedDebts,
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'analytics', child: Row(children: [Icon(Icons.pie_chart, size: 20), SizedBox(width: 8), Text('Charts & Analytics')])),
              const PopupMenuItem(value: 'receipt', child: Row(children: [Icon(Icons.receipt_long, size: 20), SizedBox(width: 8), Text('Trip Ticket Receipt')])),
              const PopupMenuItem(value: 'csv', child: Row(children: [Icon(Icons.table_chart, size: 20), SizedBox(width: 8), Text('Export to CSV')])),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'new_group', child: Row(children: [Icon(Icons.add, size: 20), SizedBox(width: 8), Text('New Group')])),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Expenses', icon: Icon(Icons.receipt_outlined)),
            Tab(text: 'Balances', icon: Icon(Icons.account_balance_wallet_outlined)),
            Tab(text: 'Activity', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Expenses List
          _buildExpensesTab(context, expenses, members, activeGroup.currency),
          // Tab 2: Balances & Simplified Debts
          _buildBalancesTab(context, simplifiedDebts, members, activeGroup),
          // Tab 3: Activity History
          _buildActivityTab(context, activeGroup.id),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }

  Widget _buildExpensesTab(
    BuildContext context,
    List<Expense> expenses,
    List<GroupMember> members,
    String currency,
  ) {
    if (expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.attach_money, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            const Text('No expenses recorded yet.'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
              ),
              child: const Text('Log First Expense'),
            ),
          ],
        ),
      );
    }

    final dateFormat = DateFormat('MMM d, yyyy');
    final memberMap = {for (final m in members) m.id: m.name};

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 80, top: 8),
      itemCount: expenses.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final exp = expenses[index];
        final date = DateTime.fromMillisecondsSinceEpoch(exp.expenseDate);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(_getCategoryIcon(exp.categoryId)),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(exp.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              if (exp.isDuplicateFlagged)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade800,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Duplicate?', style: TextStyle(fontSize: 10, color: Colors.white)),
                ),
            ],
          ),
          subtitle: Text(
            '${dateFormat.format(date)} • Paid by ${memberMap[exp.createdBy] ?? 'Member'}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Text(
            '$currency ${exp.amount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        );
      },
    );
  }

  Widget _buildBalancesTab(
    BuildContext context,
    List<DebtTransfer> transfers,
    List<GroupMember> members,
    Group group,
  ) {
    if (transfers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
            SizedBox(height: 8),
            Text('All debts are settled!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    final memberMap = {for (final m in members) m.id: m.name};

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transfers.length,
      itemBuilder: (context, index) {
        final t = transfers[index];
        final fromName = memberMap[t.fromMemberId] ?? 'Member';
        final toName = memberMap[t.toMemberId] ?? 'Member';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.arrow_forward_outlined, color: Colors.amber),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: DefaultTextStyle.of(context).style,
                          children: [
                            TextSpan(text: fromName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const TextSpan(text: ' owes '),
                            TextSpan(text: toName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${group.currency} ${t.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _recordSettlement(context, t, group),
                  child: const Text('Settle'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivityTab(BuildContext context, String groupId) {
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<AuditLog>>(
      stream: db.watchAuditLogsForGroup(groupId),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];
        if (logs.isEmpty) {
          return const Center(child: Text('No activity logged yet.'));
        }
        final dateFormat = DateFormat('MMM d, HH:mm');
        return ListView.builder(
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            final date = DateTime.fromMillisecondsSinceEpoch(log.timestamp);
            return ListTile(
              leading: const Icon(Icons.circle, size: 10, color: Colors.blueAccent),
              title: Text(log.action.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: Text(log.details ?? '', style: const TextStyle(fontSize: 12)),
              trailing: Text(dateFormat.format(date), style: const TextStyle(fontSize: 11, color: Colors.grey)),
            );
          },
        );
      },
    );
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'food': return Icons.restaurant;
      case 'transport': return Icons.directions_car;
      case 'hotel':
      case 'accommodation': return Icons.hotel;
      case 'entertainment': return Icons.movie;
      default: return Icons.local_offer;
    }
  }

  void _showCreateGroupDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Group'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Group Name (e.g. Cancun Trip)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final db = ref.read(databaseProvider);
              final now = DateTime.now().millisecondsSinceEpoch;
              final groupId = const Uuid().v4();
              final token = const Uuid().v4().substring(0, 16);

              await db.insertGroup(
                GroupsCompanion(
                  id: drift.Value(groupId),
                  name: drift.Value(nameCtrl.text.trim()),
                  groupToken: drift.Value(token),
                  currency: const drift.Value('USD'),
                  createdAt: drift.Value(now),
                  updatedAt: drift.Value(now),
                ),
              );

              // Add current user as default member
              await db.insertMember(
                GroupMembersCompanion(
                  id: drift.Value(const Uuid().v4()),
                  groupId: drift.Value(groupId),
                  name: const drift.Value('Me'),
                  isClaimed: const drift.Value(true),
                  createdAt: drift.Value(now),
                  updatedAt: drift.Value(now),
                ),
              );

              ref.read(activeGroupIdProvider.notifier).state = groupId;
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showGroupQrDialog(BuildContext context, Group group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${group.name} — Invite Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                data: 'splitcount://join?token=${group.groupToken}',
                version: QrVersions.auto,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText('Token: ${group.groupToken}', style: const TextStyle(fontFamily: 'monospace')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _recordSettlement(BuildContext context, DebtTransfer transfer, Group group) async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insertSettlement(
      SettlementsCompanion(
        id: drift.Value(const Uuid().v4()),
        groupId: drift.Value(group.id),
        payerId: drift.Value(transfer.fromMemberId),
        recipientId: drift.Value(transfer.toMemberId),
        amount: drift.Value(transfer.amount),
        settlementDate: drift.Value(now),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settlement recorded!')),
      );
    }
  }
}
