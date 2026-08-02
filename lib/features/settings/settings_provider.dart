import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class SettingsState {
  final bool showIncome;
  final bool accumulated;
  final String voiceLanguage;
  final String currency;
  final String convertFrom;
  final String convertTo;
  final String themeMode; // 'system' | 'light' | 'dark'

  const SettingsState({
    required this.showIncome,
    required this.accumulated,
    required this.voiceLanguage,
    required this.currency,
    required this.convertFrom,
    required this.convertTo,
    required this.themeMode,
  });

  SettingsState copyWith({
    bool? showIncome,
    bool? accumulated,
    String? voiceLanguage,
    String? currency,
    String? convertFrom,
    String? convertTo,
    String? themeMode,
  }) {
    return SettingsState(
      showIncome: showIncome ?? this.showIncome,
      accumulated: accumulated ?? this.accumulated,
      voiceLanguage: voiceLanguage ?? this.voiceLanguage,
      currency: currency ?? this.currency,
      convertFrom: convertFrom ?? this.convertFrom,
      convertTo: convertTo ?? this.convertTo,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsState &&
          runtimeType == other.runtimeType &&
          showIncome == other.showIncome &&
          accumulated == other.accumulated &&
          voiceLanguage == other.voiceLanguage &&
          currency == other.currency &&
          convertFrom == other.convertFrom &&
          convertTo == other.convertTo &&
          themeMode == other.themeMode;

  @override
  int get hashCode => Object.hash(
        showIncome,
        accumulated,
        voiceLanguage,
        currency,
        convertFrom,
        convertTo,
        themeMode,
      );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences _prefs;

  static const _showIncomeKey = 'settings_show_income';
  static const _accumulatedKey = 'settings_accumulated';
  static const _voiceLanguageKey = 'settings_voice_language';
  static const _currencyKey = 'settings_currency';
  static const _convertFromKey = 'settings_convert_from';
  static const _convertToKey = 'settings_convert_to';
  static const _themeModeKey = 'settings_theme_mode';

  // Tabla pública para que main.dart la use al aplicar la detección nativa
  static const countryToCurrency = {
    'CO': 'COP', 'MX': 'MXN', 'AR': 'ARS', 'BR': 'BRL', 'CL': 'CLP',
    'PE': 'PEN', 'VE': 'VES', 'EC': 'USD', 'BO': 'BOB', 'UY': 'UYU',
    'PY': 'PYG', 'CR': 'CRC', 'GT': 'GTQ', 'HN': 'HNL', 'NI': 'NIO',
    'PA': 'PAB', 'DO': 'DOP', 'CU': 'CUP',
    'US': 'USD', 'CA': 'CAD',
    'ES': 'EUR', 'DE': 'EUR', 'FR': 'EUR', 'IT': 'EUR', 'PT': 'EUR',
    'NL': 'EUR', 'BE': 'EUR', 'AT': 'EUR', 'GR': 'EUR', 'FI': 'EUR',
    'IE': 'EUR', 'LU': 'EUR',
    'GB': 'GBP', 'CH': 'CHF', 'SE': 'SEK', 'NO': 'NOK', 'DK': 'DKK',
    'JP': 'JPY', 'CN': 'CNY', 'IN': 'INR', 'KR': 'KRW', 'AU': 'AUD',
    'RU': 'RUB',
  };

  // Fuerza es-MX / MXN en esta versión, borrando cualquier valor incorrecto previo
  static const _defaultsResetKey = 'settings_defaults_reset_v1';

  SettingsNotifier(this._prefs) : super(_buildInitialState(_prefs));

  static SettingsState _buildInitialState(SharedPreferences prefs) {
    if (prefs.getBool(_defaultsResetKey) != true) {
      prefs.setString(_voiceLanguageKey, 'es-MX');
      prefs.setString(_currencyKey, 'MXN');
      prefs.setString(_convertToKey, 'MXN');
      prefs.setBool(_defaultsResetKey, true);
    }
    return SettingsState(
      showIncome: prefs.getBool(_showIncomeKey) ?? true,
      accumulated: prefs.getBool(_accumulatedKey) ?? false,
      voiceLanguage: prefs.getString(_voiceLanguageKey) ?? 'es-MX',
      currency: prefs.getString(_currencyKey) ?? 'MXN',
      convertFrom: prefs.getString(_convertFromKey) ?? 'USD',
      convertTo: prefs.getString(_convertToKey) ?? 'MXN',
      themeMode: prefs.getString(_themeModeKey) ?? 'light',
    );
  }

  void toggleShowIncome(bool value) {
    _prefs.setBool(_showIncomeKey, value);
    state = state.copyWith(showIncome: value);
  }

  void toggleAccumulated(bool value) {
    _prefs.setBool(_accumulatedKey, value);
    state = state.copyWith(accumulated: value);
  }

  void setVoiceLanguage(String lang) {
    _prefs.setString(_voiceLanguageKey, lang);
    state = state.copyWith(voiceLanguage: lang);
  }

  void setCurrency(String currency) {
    _prefs.setString(_currencyKey, currency);
    state = state.copyWith(currency: currency);
  }

  void setConvertFrom(String currency) {
    _prefs.setString(_convertFromKey, currency);
    state = state.copyWith(convertFrom: currency);
  }

  void setConvertTo(String currency) {
    _prefs.setString(_convertToKey, currency);
    state = state.copyWith(convertTo: currency);
  }

  void setThemeMode(String mode) {
    _prefs.setString(_themeModeKey, mode);
    state = state.copyWith(themeMode: mode);
  }
}
