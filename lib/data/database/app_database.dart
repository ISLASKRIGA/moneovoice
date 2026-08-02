import 'dart:io';
import 'package:drift/drift.dart' hide Transaction;
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// ── Tabla de transacciones ───────────────────────────────────
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get amount => real()();
  TextColumn get categoryName => text().nullable()();
  TextColumn get description => text()();
  DateTimeColumn get date => dateTime()();
  IntColumn get type => integer()(); // 0: gasto, 1: ingreso
  // null = Lista Privada predeterminada
  IntColumn get listId => integer().nullable().references(UserLists, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// ── Tabla de categorías ─────────────────────────────────────
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  IntColumn get iconCode => integer()();
  IntColumn get colorValue => integer()();
  IntColumn get type => integer()(); // 0: gasto, 1: ingreso
}

// ── Tabla de transacciones recurrentes ──────────────────────
class RecurringTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get amount => real()();
  TextColumn get categoryName => text().nullable()();
  TextColumn get description => text()();
  IntColumn get type => integer()(); // 0: gasto, 1: ingreso
  TextColumn get frequency => text()(); // 'weekly' | 'monthly'
  IntColumn get dayOfPeriod => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

// ── Tabla de listas de usuario ──────────────────────────────
class UserLists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get emoji => text().withDefault(const Constant('📋'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Transactions, Categories, RecurringTransactions, UserLists])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(recurringTransactions);
        await m.createTable(userLists);
      }
      if (from < 3) {
        // Añade listId a transactions (nullable, sin FK constraint en SQLite)
        await customStatement(
          'ALTER TABLE transactions ADD COLUMN list_id INTEGER REFERENCES user_lists(id)',
        );
      }
    },
  );

  // ── Transactions CRUD ──────────────────────────────────────

  Future<int> addTransaction(TransactionsCompanion entry) =>
      into(transactions).insert(entry);

  Future<bool> updateTransaction(TransactionsCompanion entry) =>
      update(transactions).replace(entry);

  /// Todas las transacciones sin filtro de lista
  Future<List<Transaction>> getAllTransactions() => (select(transactions)
        ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
      .get();

  /// Stream SIN filtro (para UI que no usa listas)
  Stream<List<Transaction>> watchAllTransactions() =>
      (select(transactions)
            ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
          .watch();

  /// Stream FILTRADO por lista:
  ///  - listId == null → Lista Privada (transactions sin lista)
  ///  - listId != null → transacciones de esa lista específica
  Stream<List<Transaction>> watchTransactionsByList(int? listId) {
    return (select(transactions)
          ..where((t) => listId == null
              ? t.listId.isNull()
              : t.listId.equals(listId))
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<void> deleteTransaction(int id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  Future<bool> isCategoryInUse(String categoryName) async {
    final txs = await (select(transactions)
          ..where((t) => t.categoryName.equals(categoryName))
          ..limit(1))
        .get();
    return txs.isNotEmpty;
  }

  // Totales globales (sin filtro)  
  Stream<double> watchTotalExpense() =>
      (select(transactions)..where((t) => t.type.equals(0)))
          .watch()
          .map((l) => l.fold(0.0, (s, t) => s + t.amount));

  Stream<double> watchTotalIncome() =>
      (select(transactions)..where((t) => t.type.equals(1)))
          .watch()
          .map((l) => l.fold(0.0, (s, t) => s + t.amount));

  // ── RecurringTransactions CRUD ─────────────────────────────

  Stream<List<RecurringTransaction>> watchRecurringTransactions() =>
      (select(recurringTransactions)
            ..orderBy([(r) => OrderingTerm(expression: r.createdAt, mode: OrderingMode.desc)]))
          .watch();

  Future<List<RecurringTransaction>> getAllRecurringTransactions() =>
      select(recurringTransactions).get();

  Future<int> addRecurringTransaction(RecurringTransactionsCompanion entry) =>
      into(recurringTransactions).insert(entry);

  Future<bool> updateRecurringTransaction(RecurringTransactionsCompanion entry) =>
      update(recurringTransactions).replace(entry);

  Future<void> deleteRecurringTransaction(int id) =>
      (delete(recurringTransactions)..where((r) => r.id.equals(id))).go();

  // ── UserLists CRUD ─────────────────────────────────────────

  Stream<List<UserList>> watchUserLists() =>
      (select(userLists)
            ..orderBy([(l) => OrderingTerm(expression: l.createdAt)]))
          .watch();

  Future<List<UserList>> getAllUserLists() =>
      select(userLists).get();

  Future<int> addUserList(UserListsCompanion entry) =>
      into(userLists).insert(entry);

  Future<void> deleteUserList(int id) =>
      (delete(userLists)..where((l) => l.id.equals(id))).go();

  Future<bool> updateUserList(UserListsCompanion entry) =>
      update(userLists).replace(entry);
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'finance_app_v1.sqlite'));
    return NativeDatabase(
      file,
      // Habilitar WAL (Write-Ahead Logging) para mejor rendimiento de concurrencia
      setup: (database) {
        database.execute('PRAGMA journal_mode=WAL;');
        database.execute('PRAGMA synchronous=NORMAL;');
      },
    );
  });
}
