import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../voice/voice_service.dart';
import '../../nlp/intent_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/settings/settings_provider.dart';
export '../../features/premium/premium_provider.dart' show premiumProvider, kFreeTransactionLimit, kFreeListLimit;

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Prefs must be overridden in main');
});

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TransactionRepository(db);
});

final voiceServiceProvider = Provider<VoiceService>((ref) {
  final service = VoiceService();
  ref.onDispose(service.dispose);
  return service;
});

final intentParserProvider = Provider<IntentParser>((ref) {
  return IntentParser();
});

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});
