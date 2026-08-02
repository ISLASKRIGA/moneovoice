import 'package:drift/drift.dart' hide Transaction;
import '../database/app_database.dart';

class TransactionRepository {
  final AppDatabase _db;

  TransactionRepository(this._db);

  // ── Streams ───────────────────────────────────────────────

  /// Stream de TODAS las transacciones (sin filtro de lista)
  Stream<List<Transaction>> watchTransactions() => _db.watchAllTransactions();

  /// Stream filtrado por lista activa:
  ///   listId == null  → Lista Privada (sin lista asignada)
  ///   listId != null  → lista específica del usuario
  Stream<List<Transaction>> watchTransactionsByList(int? listId) =>
      _db.watchTransactionsByList(listId);

  Future<List<Transaction>> getAllTransactions() => _db.getAllTransactions();

  Future<int> getTransactionCount() async {
    final all = await _db.getAllTransactions();
    return all.length;
  }

  // ── Crear ─────────────────────────────────────────────────

  Future<void> addTransaction({
    required double amount,
    required String category,
    required String description,
    required DateTime date,
    required bool isIncome,
    int? listId, // null = Lista Privada
  }) async {
    await _db.addTransaction(TransactionsCompanion(
      amount: Value(amount),
      categoryName: Value(category),
      description: Value(description),
      date: Value(date),
      type: Value(isIncome ? 1 : 0),
      listId: Value(listId),
    ));
  }

  // ── Actualizar ────────────────────────────────────────────

  Future<void> updateTransaction({
    required int id,
    required double amount,
    required String category,
    required String description,
    required DateTime date,
    required bool isIncome,
    int? listId,
  }) async {
    await _db.updateTransaction(TransactionsCompanion(
      id: Value(id),
      amount: Value(amount),
      categoryName: Value(category),
      description: Value(description),
      date: Value(date),
      type: Value(isIncome ? 1 : 0),
      listId: Value(listId),
    ));
  }

  // ── Etiquetas (Tags) ──────────────────────────────────────

  /// Reemplaza una etiqueta por otra en todas las transacciones de una lista.
  /// Si [newTag] es null o vacío, elimina la etiqueta.
  /// Todas las actualizaciones se ejecutan en una sola transacción (atómica).
  Future<int> updateTag(String oldTag, String? newTag, int? listId) async {
    final allTransactions = await _db.getAllTransactions();
    final oldPattern = '#$oldTag';
    final newPattern = (newTag == null || newTag.isEmpty) ? '' : '#$newTag';

    final toUpdate = allTransactions.where((t) {
      if (t.listId != listId) return false;
      return t.description.split(' ').contains(oldPattern);
    }).toList();

    if (toUpdate.isEmpty) return 0;

    await _db.transaction(() async {
      for (final t in toUpdate) {
        final descParts = t.description.split(' ');
        final newParts = descParts.map((word) {
          if (word == oldPattern) {
            return newPattern;
          }
          return word;
        }).where((word) => word.isNotEmpty).toList();
        
        final newDesc = newParts.join(' ').trim();
        
        await _db.updateTransaction(TransactionsCompanion(
          id: Value(t.id),
          description: Value(newDesc),
        ));
      }
    });

    return toUpdate.length;
  }

  // ── Eliminar ──────────────────────────────────────────────

  Future<void> deleteTransaction(int id) => _db.deleteTransaction(id);

  // ── Utilidades ────────────────────────────────────────────

  Future<bool> isCategoryInUse(String categoryName) =>
      _db.isCategoryInUse(categoryName);

  Stream<double> watchTotalIncome() => _db.watchTotalIncome();
  Stream<double> watchTotalExpense() => _db.watchTotalExpense();
}
