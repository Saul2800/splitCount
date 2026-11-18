import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../../providers/app_providers.dart';
import '../../../data/local/app_database.dart';
import '../../../core/utils/duplicate_detector.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _selectedCategory = 'food';
  String _splitType = 'equal'; // 'equal', 'exact', 'percentage', 'shares'
  String? _singlePayerId;
  bool _isMultiPayer = false;

  final Map<String, double> _payerAmounts = {};
  final Map<String, double> _splitValues = {};
  final Set<String> _selectedMemberIds = {};

  DuplicateMatch? _potentialDuplicate;

  final List<Map<String, dynamic>> _categories = [
    {'id': 'food', 'name': 'Food & Drinks', 'icon': Icons.restaurant},
    {'id': 'transport', 'name': 'Transport', 'icon': Icons.directions_car},
    {'id': 'hotel', 'name': 'Hotel & Lodging', 'icon': Icons.hotel},
    {'id': 'entertainment', 'name': 'Activities', 'icon': Icons.movie},
    {'id': 'supplies', 'name': 'Supplies / Groceries', 'icon': Icons.shopping_cart},
  ];

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(_checkForDuplicates);
    _titleCtrl.addListener(_checkForDuplicates);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _checkForDuplicates() {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      if (_potentialDuplicate != null) setState(() => _potentialDuplicate = null);
      return;
    }

    final expenses = ref.read(groupExpensesProvider).value ?? [];
    final match = DuplicateDetector.findPotentialDuplicate(
      newAmount: amount,
      newDateMs: DateTime.now().millisecondsSinceEpoch,
      newCategoryId: _selectedCategory,
      newTitle: _titleCtrl.text,
      existingExpenses: expenses,
    );

    setState(() => _potentialDuplicate = match);
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(activeGroupProvider);
    final members = ref.watch(groupMembersProvider).value ?? [];

    if (group == null) return const Scaffold(body: Center(child: Text('No active group')));

    if (_singlePayerId == null && members.isNotEmpty) {
      _singlePayerId = members.first.id;
      _selectedMemberIds.addAll(members.map((m) => m.id));
    }

    final totalAmount = double.tryParse(_amountCtrl.text) ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => _saveExpense(context, group, members),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Duplicate Warning Banner
            if (_potentialDuplicate != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade700),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Potential Duplicate Detected', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            'Matches "${_potentialDuplicate!.existingExpense.title}" for ${group.currency} ${_potentialDuplicate!.existingExpense.amount.toStringAsFixed(2)} (${_potentialDuplicate!.reason})',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Amount Field
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: '${group.currency} ',
                labelText: 'Amount',
                hintText: '0.00',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Title Field
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'What was this expense for?',
                hintText: 'e.g. Dinner at Beach',
                prefixIcon: Icon(Icons.description),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Category Selector
            const Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat['id'];
                return ChoiceChip(
                  avatar: Icon(cat['icon'] as IconData, size: 16),
                  label: Text(cat['name'] as String),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCategory = cat['id'] as String);
                      _checkForDuplicates();
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Paid By Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Paid By', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => setState(() => _isMultiPayer = !_isMultiPayer),
                  child: Text(_isMultiPayer ? 'Switch to Single Payer' : 'Multiple People Paid'),
                ),
              ],
            ),
            if (!_isMultiPayer)
              DropdownButtonFormField<String>(
                value: _singlePayerId,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: members.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(),
                onChanged: (id) => setState(() => _singlePayerId = id),
              )
            else
              ...members.map((m) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(m.name)),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            prefixText: '${group.currency} ',
                            hintText: '0.00',
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (v) => _payerAmounts[m.id] = double.tryParse(v) ?? 0.0,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 24),

            // Split Mode Section
            const Text('Split Method', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'equal', label: Text('Equally')),
                ButtonSegment(value: 'exact', label: Text('Exact')),
                ButtonSegment(value: 'percentage', label: Text('%')),
                ButtonSegment(value: 'shares', label: Text('Shares')),
              ],
              selected: {_splitType},
              onSelectionChanged: (val) => setState(() => _splitType = val.first),
            ),
            const SizedBox(height: 16),

            // Split Breakdown
            ...members.map((m) {
              final isSelected = _selectedMemberIds.contains(m.id);
              return CheckboxListTile(
                value: isSelected,
                title: Text(m.name),
                subtitle: _splitType == 'equal'
                    ? (isSelected && _selectedMemberIds.isNotEmpty
                        ? Text('${group.currency} ${(totalAmount / _selectedMemberIds.length).toStringAsFixed(2)}')
                        : null)
                    : SizedBox(
                        width: 100,
                        child: TextField(
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: _splitType == 'percentage' ? '0 %' : (_splitType == 'shares' ? '1 share' : '${group.currency} 0.00'),
                            isDense: true,
                          ),
                          onChanged: (v) => _splitValues[m.id] = double.tryParse(v) ?? 0.0,
                        ),
                      ),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedMemberIds.add(m.id);
                    } else {
                      _selectedMemberIds.remove(m.id);
                    }
                  });
                },
              );
            }),
            const SizedBox(height: 16),

            // Add Shadow Member button
            OutlinedButton.icon(
              onPressed: () => _showAddMemberDialog(context, group.id),
              icon: const Icon(Icons.person_add),
              label: const Text('Add Friend to Group'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context, String groupId) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Friend (Placeholder)'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Friend Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final db = ref.read(databaseProvider);
              final now = DateTime.now().millisecondsSinceEpoch;
              await db.insertMember(
                GroupMembersCompanion(
                  id: drift.Value(const Uuid().v4()),
                  groupId: drift.Value(groupId),
                  name: drift.Value(nameCtrl.text.trim()),
                  createdAt: drift.Value(now),
                  updatedAt: drift.Value(now),
                ),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveExpense(BuildContext context, Group group, List<GroupMember> members) async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount')));
      return;
    }
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an expense title')));
      return;
    }

    final db = ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final expenseId = const Uuid().v4();

    // Setup Payers
    final List<ExpensePayersCompanion> payers = [];
    if (!_isMultiPayer) {
      payers.add(
        ExpensePayersCompanion(
          id: drift.Value(const Uuid().v4()),
          expenseId: drift.Value(expenseId),
          memberId: drift.Value(_singlePayerId!),
          amountPaid: drift.Value(amount),
        ),
      );
    } else {
      _payerAmounts.forEach((memberId, paid) {
        if (paid > 0) {
          payers.add(
            ExpensePayersCompanion(
              id: drift.Value(const Uuid().v4()),
              expenseId: drift.Value(expenseId),
              memberId: drift.Value(memberId),
              amountPaid: drift.Value(paid),
            ),
          );
        }
      });
    }

    // Setup Splits
    final List<ExpenseSplitsCompanion> splits = [];
    if (_splitType == 'equal' && _selectedMemberIds.isNotEmpty) {
      final splitPerPerson = amount / _selectedMemberIds.length;
      for (final mId in _selectedMemberIds) {
        splits.add(
          ExpenseSplitsCompanion(
            id: drift.Value(const Uuid().v4()),
            expenseId: drift.Value(expenseId),
            memberId: drift.Value(mId),
            amountOwed: drift.Value(splitPerPerson),
          ),
        );
      }
    } else {
      _splitValues.forEach((mId, val) {
        if (_selectedMemberIds.contains(mId) && val > 0) {
          splits.add(
            ExpenseSplitsCompanion(
              id: drift.Value(const Uuid().v4()),
              expenseId: drift.Value(expenseId),
              memberId: drift.Value(mId),
              amountOwed: drift.Value(val),
              splitValue: drift.Value(val),
            ),
          );
        }
      });
    }

    await db.saveExpenseWithDetails(
      expense: ExpensesCompanion(
        id: drift.Value(expenseId),
        groupId: drift.Value(group.id),
        title: drift.Value(_titleCtrl.text.trim()),
        amount: drift.Value(amount),
        currency: drift.Value(group.currency),
        categoryId: drift.Value(_selectedCategory),
        splitType: drift.Value(_splitType),
        expenseDate: drift.Value(now),
        notes: drift.Value(_notesCtrl.text.trim()),
        createdBy: drift.Value(_singlePayerId ?? members.first.id),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
        isDuplicateFlagged: drift.Value(_potentialDuplicate != null),
      ),
      payers: payers,
      splits: splits,
    );

    // Record audit log
    await db.insertAuditLog(
      AuditLogsCompanion(
        id: drift.Value(const Uuid().v4()),
        groupId: drift.Value(group.id),
        actorId: drift.Value(_singlePayerId ?? 'User'),
        action: const drift.Value('create_expense'),
        entityId: drift.Value(expenseId),
        details: drift.Value('Added "${_titleCtrl.text}" for ${group.currency} ${amount.toStringAsFixed(2)}'),
        timestamp: drift.Value(now),
      ),
    );

    if (context.mounted) Navigator.pop(context);
  }
}
