import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  static final SecurityService instance = SecurityService._init();
  static const String _pinKey = 'app_pin_code';
  static const String _pinEnabledKey = 'app_pin_enabled';

  String _webMemoryPin = '1515'; // PIN por defecto para web
  bool _webMemoryPinEnabled = true;

  SecurityService._init();

  Future<String> getPin() async {
    if (kIsWeb) return _webMemoryPin;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_pinKey) ?? '1515';
    } catch (_) {
      return '1515';
    }
  }

  Future<bool> isPinEnabled() async {
    if (kIsWeb) return _webMemoryPinEnabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_pinEnabledKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<bool> verifyPin(String inputPin) async {
    final currentPin = await getPin();
    return inputPin == currentPin;
  }

  Future<void> savePin(String newPin) async {
    if (kIsWeb) {
      _webMemoryPin = newPin;
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pinKey, newPin);
    } catch (e) {
      print('Error al guardar PIN: $e');
    }
  }

  Future<void> setPinEnabled(bool enabled) async {
    if (kIsWeb) {
      _webMemoryPinEnabled = enabled;
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_pinEnabledKey, enabled);
    } catch (e) {
      print('Error al actualizar estado del PIN: $e');
    }
  }
}
