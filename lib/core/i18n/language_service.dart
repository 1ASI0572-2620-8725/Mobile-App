import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _storageKey = 'fs_lang';
const supportedLanguages = ['en', 'es'];

/// Equivalente a `core/i18n/language.service.ts` + `@ngx-translate`.
/// Usa los mismos archivos `i18n/es.json` y `i18n/en.json` del front web.
class LanguageService extends ChangeNotifier {
  String _current = 'en';
  Map<String, dynamic> _strings = {};
  Map<String, dynamic> _fallback = {};

  String get current => _current;

  Future<void> init() async {
    _fallback = await _load('en');
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    await use(saved ?? _autoFromDevice());
  }

  String _autoFromDevice() => ui.PlatformDispatcher.instance.locale.languageCode.toLowerCase().startsWith('es') ? 'es' : 'en';

  Future<Map<String, dynamic>> _load(String lang) async {
    final raw = await rootBundle.loadString('assets/i18n/$lang.json');
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> use(String lang) async {
    if (!supportedLanguages.contains(lang)) lang = 'en';
    _strings = lang == 'en' && _fallback.isNotEmpty ? _fallback : await _load(lang);
    _current = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, lang);
    notifyListeners();
  }

  Future<void> toggle() => use(_current == 'en' ? 'es' : 'en');

  /// Traduce una clave con puntos (`home.kpi.products`) e interpola `{{param}}`.
  String t(String key, [Map<String, Object?> params = const {}]) {
    var value = _lookup(_strings, key) ?? _lookup(_fallback, key) ?? key;
    params.forEach((k, v) => value = value.replaceAll(RegExp('{{\\s*$k\\s*}}'), '${v ?? ''}'));
    return value;
  }

  String? _lookup(Map<String, dynamic> map, String key) {
    dynamic node = map;
    for (final part in key.split('.')) {
      if (node is Map<String, dynamic> && node.containsKey(part)) {
        node = node[part];
      } else {
        return null;
      }
    }
    return node is String ? node : null;
  }
}

/// Atajos equivalentes al pipe `| translate` y a `TranslateService.instant()`.
extension TranslateX on BuildContext {
  /// Para usar dentro de `build` (se redibuja al cambiar el idioma).
  String tr(String key, [Map<String, Object?> params = const {}]) => watch<LanguageService>().t(key, params);

  /// Para usar en callbacks (botones, validaciones).
  String trNow(String key, [Map<String, Object?> params = const {}]) => read<LanguageService>().t(key, params);
}
