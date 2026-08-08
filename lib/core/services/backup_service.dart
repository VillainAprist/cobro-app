import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/loan_model.dart';
import 'database_helper.dart';

class BackupService {
  static final BackupService instance = BackupService._init();
  BackupService._init();

  /// Exporta todos los préstamos a un archivo JSON y abre el diálogo para compartir/guardar
  Future<bool> exportJson(List<LoanModel> loans) async {
    try {
      final jsonList = loans.map((l) => l.toJson()).toList();
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);

      final tempDir = await getTemporaryDirectory();
      final dateStr = DateTime.now().toIso8601String().split('T').first;
      final file = File('${tempDir.path}/respaldo_prestamos_$dateStr.json');
      await file.writeAsString(jsonString);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Copia de Seguridad - Registro de Préstamos',
        text: 'Respaldo completo de préstamos en formato JSON.',
      );
      return true;
    } catch (e) {
      print('Error al exportar JSON: $e');
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

      final tempDir = await getTemporaryDirectory();
      final dateStr = DateTime.now().toIso8601String().split('T').first;
      final file = File('${tempDir.path}/prestamos_$dateStr.csv');
      await file.writeAsString(csvData);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Reporte Excel CSV - Registro de Préstamos',
        text: 'Reporte de préstamos exportado a CSV.',
      );
      return true;
    } catch (e) {
      print('Error al exportar CSV: $e');
      return false;
    }
  }

  /// Permite al usuario elegir un archivo JSON previamente exportado para restaurar los préstamos
  Future<int?> importJson() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final List<dynamic> decoded = jsonDecode(content);

        final loans = decoded.map((item) => LoanModel.fromJson(item as Map<String, dynamic>)).toList();

        // Reemplazar la base de datos con los nuevos préstamos cargados
        await DatabaseHelper.instance.replaceAllLoans(loans);
        return loans.length;
      }
      return null;
    } catch (e) {
      print('Error al importar respaldo: $e');
      rethrow;
    }
  }
}
