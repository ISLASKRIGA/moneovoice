import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/di/dependency_injection.dart';

@immutable
class CategoryItem {
  final String name;
  final String emoji;

  const CategoryItem({required this.name, required this.emoji});

  Map<String, dynamic> toJson() => {'name': name, 'emoji': emoji};

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    return CategoryItem(
      name: json['name'] as String,
      emoji: json['emoji'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryItem &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          emoji == other.emoji;

  @override
  int get hashCode => Object.hash(name, emoji);
}

class CategoryNotifier extends StateNotifier<List<CategoryItem>> {
  final SharedPreferences _prefs;
  static const _categoriesKey = 'settings_categories';

  CategoryNotifier(this._prefs) : super(_loadCategories(_prefs));

  static List<CategoryItem> _loadCategories(SharedPreferences prefs) {
    final String? jsonStr = prefs.getString(_categoriesKey);
    if (jsonStr != null) {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => CategoryItem.fromJson(e as Map<String, dynamic>)).toList();
    }

    // Categorías por defecto
    return const [
      CategoryItem(name: 'Comida', emoji: '🍔'),
      CategoryItem(name: 'Transporte', emoji: '🚗'),
      CategoryItem(name: 'Ropa', emoji: '🛍️'),
      CategoryItem(name: 'Juegos', emoji: '🎮'),
      CategoryItem(name: 'Salud', emoji: '💊'),
      CategoryItem(name: 'Super', emoji: '🥬'),
    ];
  }

  void _saveCategories(List<CategoryItem> categories) {
    _prefs.setString(_categoriesKey, jsonEncode(categories.map((c) => c.toJson()).toList()));
    state = categories;
  }

  void addCategory(String name, String emoji) {
    final newCategories = [...state, CategoryItem(name: name, emoji: emoji)];
    _saveCategories(newCategories);
  }

  void removeCategory(String name) {
    final newCategories = state.where((c) => c.name != name).toList();
    _saveCategories(newCategories);
  }

  void updateCategory(String oldName, String newName, String newEmoji) {
    final newCategories = state.map((c) {
      if (c.name == oldName) {
        return CategoryItem(name: newName.trim().isEmpty ? oldName : newName.trim(), emoji: newEmoji);
      }
      return c;
    }).toList();
    _saveCategories(newCategories);
  }
}

final categoryProvider = StateNotifierProvider<CategoryNotifier, List<CategoryItem>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CategoryNotifier(prefs);
});
