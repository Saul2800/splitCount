import 'package:drift/drift.dart';

class Groups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  TextColumn get groupToken => text().unique()();
  TextColumn get imageUrl => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class GroupMembers extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().references(Groups, #id)();
  TextColumn get name => text()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get deviceId => text().nullable()();
  BoolColumn get isClaimed => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().nullable().references(Groups, #id)();
  TextColumn get name => text()();
  TextColumn get icon => text()();
  TextColumn get color => text()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().references(Groups, #id)();
  TextColumn get title => text()();
  RealColumn get amount => real()();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  TextColumn get categoryId => text()();
  TextColumn get splitType => text()(); // 'equal', 'exact', 'percentage', 'shares'
  IntColumn get expenseDate => integer()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdBy => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isDuplicateFlagged => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class ExpensePayers extends Table {
  TextColumn get id => text()();
  TextColumn get expenseId => text().references(Expenses, #id)();
  TextColumn get memberId => text().references(GroupMembers, #id)();
  RealColumn get amountPaid => real()();

  @override
  Set<Column> get primaryKey => {id};
}

class ExpenseSplits extends Table {
  TextColumn get id => text()();
  TextColumn get expenseId => text().references(Expenses, #id)();
  TextColumn get memberId => text().references(GroupMembers, #id)();
  RealColumn get amountOwed => real()();
  RealColumn get splitValue => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Settlements extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().references(Groups, #id)();
  @ReferenceName('payerSettlements')
  TextColumn get payerId => text().references(GroupMembers, #id)();
  @ReferenceName('recipientSettlements')
  TextColumn get recipientId => text().references(GroupMembers, #id)();
  RealColumn get amount => real()();
  IntColumn get settlementDate => integer()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class AuditLogs extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().references(Groups, #id)();
  TextColumn get actorId => text()();
  TextColumn get action => text()(); // 'create_expense', 'edit_expense', 'delete_expense', 'settle'
  TextColumn get entityId => text()();
  TextColumn get details => text().nullable()();
  IntColumn get timestamp => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
