import 'package:intl/intl.dart';

typedef JsonMap = Map<String, Object?>;

int rupeesToMinor(String value) =>
    ((double.tryParse(value.trim()) ?? 0) * 100).round();

String formatMoney(int minorUnits, {String locale = 'en_IN'}) =>
    NumberFormat.currency(
      locale: locale,
      symbol: '₹',
      decimalDigits: 0,
    ).format(minorUnits / 100);

String formatDateOnly(DateTime value) => DateFormat('yyyy-MM-dd').format(value);

abstract class SyncEntity {
  const SyncEntity({
    required this.id,
    required this.householdId,
    required this.createdBy,
    required this.deviceId,
    required this.createdAt,
    required this.updatedAt,
    required this.revision,
    required this.deleted,
  });

  final String id;
  final String householdId;
  final String createdBy;
  final String deviceId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;
  final bool deleted;

  JsonMap syncFields() => {
    'id': id,
    'household_id': householdId,
    'created_by': createdBy,
    'device_id': deviceId,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'revision': revision,
    'is_deleted': deleted ? 1 : 0,
    'sync_state': 'pending',
  };
}

class Expense extends SyncEntity {
  const Expense({
    required super.id,
    required super.householdId,
    required super.createdBy,
    required super.deviceId,
    required super.createdAt,
    required super.updatedAt,
    required super.revision,
    required super.deleted,
    required this.amountMinor,
    required this.category,
    required this.paidBy,
    required this.paymentMode,
    required this.date,
    required this.notes,
  });

  final int amountMinor;
  final String category;
  final String paidBy;
  final String paymentMode;
  final DateTime date;
  final String notes;

  factory Expense.fromMap(JsonMap map) => Expense(
    id: map['id']! as String,
    householdId: map['household_id']! as String,
    createdBy: map['created_by']! as String,
    deviceId: map['device_id']! as String,
    createdAt: DateTime.parse(map['created_at']! as String),
    updatedAt: DateTime.parse(map['updated_at']! as String),
    revision: map['revision']! as int,
    deleted: (map['is_deleted']! as int) == 1,
    amountMinor: map['amount_minor']! as int,
    category: map['category']! as String,
    paidBy: map['paid_by']! as String,
    paymentMode: map['payment_mode']! as String,
    date: DateTime.parse(map['date']! as String),
    notes: map['notes']! as String,
  );

  JsonMap toMap() => {
    ...syncFields(),
    'amount_minor': amountMinor,
    'category': category,
    'paid_by': paidBy,
    'payment_mode': paymentMode,
    'date': formatDateOnly(date),
    'notes': notes,
  };
}

class IncomeEntry extends SyncEntity {
  const IncomeEntry({
    required super.id,
    required super.householdId,
    required super.createdBy,
    required super.deviceId,
    required super.createdAt,
    required super.updatedAt,
    required super.revision,
    required super.deleted,
    required this.source,
    required this.amountMinor,
    required this.receivedDate,
  });

  final String source;
  final int amountMinor;
  final DateTime receivedDate;

  factory IncomeEntry.fromMap(JsonMap map) => IncomeEntry(
    id: map['id']! as String,
    householdId: map['household_id']! as String,
    createdBy: map['created_by']! as String,
    deviceId: map['device_id']! as String,
    createdAt: DateTime.parse(map['created_at']! as String),
    updatedAt: DateTime.parse(map['updated_at']! as String),
    revision: map['revision']! as int,
    deleted: (map['is_deleted']! as int) == 1,
    source: map['source']! as String,
    amountMinor: map['amount_minor']! as int,
    receivedDate: DateTime.parse(map['received_date']! as String),
  );

  JsonMap toMap() => {
    ...syncFields(),
    'source': source,
    'amount_minor': amountMinor,
    'received_date': formatDateOnly(receivedDate),
  };
}

class Emi extends SyncEntity {
  const Emi({
    required super.id,
    required super.householdId,
    required super.createdBy,
    required super.deviceId,
    required super.createdAt,
    required super.updatedAt,
    required super.revision,
    required super.deleted,
    required this.loanName,
    required this.amountMinor,
    required this.dueDate,
    required this.paid,
  });

  final String loanName;
  final int amountMinor;
  final DateTime dueDate;
  final bool paid;

  factory Emi.fromMap(JsonMap map) => Emi(
    id: map['id']! as String,
    householdId: map['household_id']! as String,
    createdBy: map['created_by']! as String,
    deviceId: map['device_id']! as String,
    createdAt: DateTime.parse(map['created_at']! as String),
    updatedAt: DateTime.parse(map['updated_at']! as String),
    revision: map['revision']! as int,
    deleted: (map['is_deleted']! as int) == 1,
    loanName: map['loan_name']! as String,
    amountMinor: map['amount_minor']! as int,
    dueDate: DateTime.parse(map['due_date']! as String),
    paid: (map['status']! as String) == 'paid',
  );

  JsonMap toMap() => {
    ...syncFields(),
    'loan_name': loanName,
    'amount_minor': amountMinor,
    'due_date': formatDateOnly(dueDate),
    'status': paid ? 'paid' : 'due',
  };
}

class Budget extends SyncEntity {
  const Budget({
    required super.id,
    required super.householdId,
    required super.createdBy,
    required super.deviceId,
    required super.createdAt,
    required super.updatedAt,
    required super.revision,
    required super.deleted,
    required this.category,
    required this.limitMinor,
    required this.month,
  });

  final String category;
  final int limitMinor;
  final String month;

  factory Budget.fromMap(JsonMap map) => Budget(
    id: map['id']! as String,
    householdId: map['household_id']! as String,
    createdBy: map['created_by']! as String,
    deviceId: map['device_id']! as String,
    createdAt: DateTime.parse(map['created_at']! as String),
    updatedAt: DateTime.parse(map['updated_at']! as String),
    revision: map['revision']! as int,
    deleted: (map['is_deleted']! as int) == 1,
    category: map['category']! as String,
    limitMinor: map['limit_minor']! as int,
    month: map['month']! as String,
  );

  JsonMap toMap() => {
    ...syncFields(),
    'category': category,
    'limit_minor': limitMinor,
    'month': month,
  };
}

class FinanceSnapshot {
  const FinanceSnapshot({
    this.expenses = const [],
    this.income = const [],
    this.emis = const [],
    this.budgets = const [],
  });

  final List<Expense> expenses;
  final List<IncomeEntry> income;
  final List<Emi> emis;
  final List<Budget> budgets;

  bool _thisMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  int get monthlyExpenses => expenses
      .where((item) => !item.deleted && _thisMonth(item.date))
      .fold(0, (sum, item) => sum + item.amountMinor);

  int get monthlyIncome => income
      .where((item) => !item.deleted && _thisMonth(item.receivedDate))
      .fold(0, (sum, item) => sum + item.amountMinor);

  int get emiDue => emis
      .where((item) => !item.deleted && !item.paid && _thisMonth(item.dueDate))
      .fold(0, (sum, item) => sum + item.amountMinor);

  int get moneyLeft => monthlyIncome - monthlyExpenses - emiDue;

  Map<String, int> get categoryTotals {
    final totals = <String, int>{};
    for (final expense in expenses.where(
      (item) => !item.deleted && _thisMonth(item.date),
    )) {
      totals.update(
        expense.category,
        (value) => value + expense.amountMinor,
        ifAbsent: () => expense.amountMinor,
      );
    }
    return totals;
  }
}
