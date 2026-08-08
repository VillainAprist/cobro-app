import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/loan_model.dart';

class FirebaseSyncService {
  static final FirebaseSyncService instance = FirebaseSyncService._init();
  static const String _freqKey = 'cloud_auto_backup_frequency';
  static const String _lastBackupKey = 'cloud_last_backup_date';

  bool _initialized = false;

  FirebaseSyncService._init();

  Future<bool> init() async {
    if (_initialized) return true;
    try {
      if (Firebase.apps.isNotEmpty) {
        _initialized = true;
        return true;
      }
      await Firebase.initializeApp();
      _initialized = true;
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Firebase init warning (sube google-services.json para habilitar en celular): $e');
      }
      return false;
    }
  }

  /// Obtiene la frecuencia de respaldo guardada ('Diario', '3dias', 'Semanal', '20dias', 'Manual')
  Future<String> getAutoBackupFrequency() async {
    if (kIsWeb) return 'Diario';
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_freqKey) ?? 'Diario';
    } catch (_) {
      return 'Diario';
    }
  }

  /// Guarda la preferencia de frecuencia elegida por el usuario
  Future<void> saveAutoBackupFrequency(String frequency) async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_freqKey, frequency);
    } catch (e) {
      if (kDebugMode) print('Error al guardar frecuencia: $e');
    }
  }

  /// Obtiene la fecha y hora del último respaldo registrado
  Future<DateTime?> getLastBackupDate() async {
    if (kIsWeb) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_lastBackupKey);
      return str != null ? DateTime.parse(str) : null;
    } catch (_) {
      return null;
    }
  }

  /// Respalda la lista completa de préstamos en Firebase Firestore
  Future<bool> backupToCloud(List<LoanModel> loans) async {
    final ready = await init();
    if (!ready) return false;

    try {
      final collection = FirebaseFirestore.instance.collection('loans_backup');
      final now = DateTime.now();

      final backupData = {
        'timestamp': FieldValue.serverTimestamp(),
        'updatedAt': now.toIso8601String(),
        'totalLoans': loans.length,
        'loans': loans.map((l) => l.toJson()).toList(),
      };

      await collection.doc('daily_backup').set(backupData);

      if (!kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastBackupKey, now.toIso8601String());
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error en respaldo automático Firebase: $e');
      }
      return false;
    }
  }

  /// Evalúa en segundo plano si ha transcurrido el tiempo según la frecuencia elegida y respalda silenciosamente
  Future<bool> checkAndRunAutoBackup(List<LoanModel> loans) async {
    if (loans.isEmpty) return false;

    final freq = await getAutoBackupFrequency();
    if (freq == 'Manual') return false;

    final lastBackup = await getLastBackupDate();
    if (lastBackup == null) {
      return await backupToCloud(loans);
    }

    final daysDifference = DateTime.now().difference(lastBackup).inDays;
    int requiredDays = 1;

    switch (freq) {
      case 'Cada 3 días':
        requiredDays = 3;
        break;
      case 'Semanal':
        requiredDays = 7;
        break;
      case 'Cada 20 días':
        requiredDays = 20;
        break;
      case 'Diario':
      default:
        requiredDays = 1;
        break;
    }

    if (daysDifference >= requiredDays) {
      return await backupToCloud(loans);
    }

    return false;
  }

  /// Descarga el último respaldo desde Firebase Firestore
  Future<List<LoanModel>?> restoreFromCloud() async {
    final ready = await init();
    if (!ready) return null;

    try {
      final doc = await FirebaseFirestore.instance.collection('loans_backup').doc('daily_backup').get();

      if (!doc.exists || doc.data() == null) return null;

      final data = doc.data()!;
      final rawLoans = data['loans'] as List<dynamic>?;
      if (rawLoans == null) return null;

      return rawLoans.map((json) => LoanModel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error al restaurar desde Firebase: $e');
      }
      return null;
    }
  }
}
