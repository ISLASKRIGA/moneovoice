import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Transaction;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import '../../core/di/dependency_injection.dart';
import '../../data/database/app_database.dart';

/// Stream de todas las listas del usuario
final userListsProvider = StreamProvider<List<UserList>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchUserLists();
});

// ── Propiedades de la Lista 1 (Lista por defecto) ──────────
class DefaultListSettings {
  final String name;
  final String emoji;
  final bool isDeleted;
  DefaultListSettings({required this.name, required this.emoji, this.isDeleted = false});
}

class DefaultListNotifier extends StateNotifier<DefaultListSettings> {
  final SharedPreferences _prefs;
  static const _nameKey = 'default_list_name';
  static const _emojiKey = 'default_list_emoji';
  static const _deletedKey = 'default_list_deleted';

  DefaultListNotifier(this._prefs)
      : super(DefaultListSettings(
          name: _prefs.getString(_nameKey) ?? 'Lista 1',
          emoji: _prefs.getString(_emojiKey) ?? '⭐',
          isDeleted: _prefs.getBool(_deletedKey) ?? false,
        ));

  Future<void> update(String name, String emoji) async {
    await _prefs.setString(_nameKey, name);
    await _prefs.setString(_emojiKey, emoji);
    state = DefaultListSettings(name: name, emoji: emoji, isDeleted: state.isDeleted);
  }

  Future<void> delete() async {
    await _prefs.setBool(_deletedKey, true);
    state = DefaultListSettings(name: state.name, emoji: state.emoji, isDeleted: true);
  }

  Future<void> restore() async {
    await _prefs.setBool(_deletedKey, false);
    state = DefaultListSettings(name: state.name, emoji: state.emoji, isDeleted: false);
  }
}

final defaultListProvider =
    StateNotifierProvider<DefaultListNotifier, DefaultListSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DefaultListNotifier(prefs);
});

// ── Lista activa (null = "Lista 1" por defecto) ────────
class ActiveListNotifier extends StateNotifier<UserList?> {
  final SharedPreferences _prefs;
  final AppDatabase _db;
  static const _key = 'active_list_id';

  ActiveListNotifier(this._prefs, this._db) : super(null) {
    _restore();
  }

  Future<void> _restore() async {
    final savedId = _prefs.getInt(_key);
    if (savedId == null) return;

    final lists = await _db.getAllUserLists();
    // firstWhereOrNull devuelve null si no hay coincidencia (lista fue borrada)
    state = lists.firstWhereOrNull((l) => l.id == savedId);
  }

  void select(UserList? list) {
    state = list;
    if (list == null) {
      _prefs.remove(_key);
    } else {
      _prefs.setInt(_key, list.id);
    }
  }

  void clearIfDeleted(int deletedId) {
    if (state?.id == deletedId) {
      state = null;
      _prefs.remove(_key);
    }
  }
}

final activeListProvider = StateNotifierProvider<ActiveListNotifier, UserList?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final db = ref.watch(databaseProvider);
  return ActiveListNotifier(prefs, db);
});

// ── CRUD de listas ────────────────────────────────────────
class ListsNotifier extends StateNotifier<AsyncValue<List<UserList>>> {
  final AppDatabase _db;
  final Ref _ref;

  ListsNotifier(this._db, this._ref) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    final lists = await _db.getAllUserLists();
    state = AsyncValue.data(lists);
  }

  Future<void> add({required String name, required String emoji}) async {
    await _db.addUserList(UserListsCompanion(
      name: Value(name),
      emoji: Value(emoji),
    ));
    await _load();
  }

  Future<void> rename(UserList list, String newName, {String? emoji}) async {
    await _db.updateUserList(UserListsCompanion(
      id: Value(list.id),
      name: Value(newName),
      emoji: Value(emoji ?? list.emoji),
    ));
    await _load();
  }

  Future<void> delete(int id) async {
    await _db.deleteUserList(id);
    // Si era la lista activa, la limpiamos
    _ref.read(activeListProvider.notifier).clearIfDeleted(id);
    final lists = await _db.getAllUserLists();
    
    // Si ya no quedan listas de usuario, restauramos la Lista 1 por defecto
    if (lists.isEmpty) {
      await _ref.read(defaultListProvider.notifier).restore();
    }
    
    state = AsyncValue.data(lists);
  }
}

final listsNotifierProvider =
    StateNotifierProvider<ListsNotifier, AsyncValue<List<UserList>>>((ref) {
  final db = ref.watch(databaseProvider);
  return ListsNotifier(db, ref);
});
