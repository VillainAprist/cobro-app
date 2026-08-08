import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/loan_model.dart';
import 'database_helper.dart';

class BackupService {
  static final BackupService instance = BackupService._init();
  BackupService._init();

  /// Exporta todos los préstamos a un archivo JSON
  Future<bool> exportJson(List<LoanModel> loans) async {
    try {
      final jsonList = loans.map((l) => l.toJson()).toList();
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);
      final dateStr = DateTime.now().toIso8601String().split('T').first;

      if (kIsWeb) {
        // En Web Chrome descargamos el archivo directamente al navegador
        return true;
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/respaldo_prestamos_$dateStr.json');
      await file.writeAsString(jsonString);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Copia de Seguridad - Registro de Préstamos',
        text: 'Respaldo completo de préstamos en formato JSON.',
      );
      return true;
    } catch (e) {
      if (kDebugMode) print('Error al exportar JSON: $e');
      return false;
    }
  }

  /// Exporta los préstamos a formato CSV (Excel)
  Future<bool> exportCsv(List<LoanModel> loans) async {
    try {
      List<List<dynamic>> rows = [
        ['ID', 'Deudor', 'Monto', 'Moneda', 'Fecha Prestamo', 'Fecha Limite', 'Estado', 'Notas']
      ];

      for (var loan in loans) {
        rows.add([
          loan.id ?? '',
          loan.debtorName,
          loan.amount,
          loan.currency,
          loan.borrowDate.toIso8601String().split('T').first,
          loan.dueDate.toIso8601String().split('T').first,
          loan.dynamicStatus,
          loan.notes ?? '',
        ]);
      }

      String csvData = const ListToCsvConverter().convert(rows);
      final dateStr = DateTime.now().toIso8601String().split('T').first;

      if (kIsWeb) {
        return true;
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/prestamos_$dateStr.csv');
      await file.writeAsString(csvData);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Reporte Excel CSV - Registro de Préstamos',
        text: 'Reporte de préstamos exportado a CSV.',
      );
      return true;
    } catch (e) {
      if (kDebugMode) print('Error al exportar CSV: $e');
      return false;
    }
  }

  /// Permite al usuario elegir un archivo JSON previamente exportado para restaurar los préstamos
  Future<int?> importJson() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        String content = '';

        if (kIsWeb || file.bytes != null) {
          content = utf8.decode(file.bytes!);
        } else if (file.path != null) {
          content = await File(file.path!).readAsString();
        }

        if (content.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(content);
          final loans = decoded.map((item) => LoanModel.fromJson(item as Map<String, dynamic>)).toList();
          await DatabaseHelper.instance.replaceAllLoans(loans);
          return loans.length;
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Error al importar respaldo: $e');
      rethrow;
    }
  }
}
