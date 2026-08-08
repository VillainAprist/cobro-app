import 'package:flutter/material.dart';
import '../core/constants/app_theme.dart';
import '../core/services/backup_service.dart';
import '../core/services/database_helper.dart';
import '../core/services/firebase_sync_service.dart';
import '../core/services/security_service.dart';
import '../core/utils/formatters.dart';
import '../models/loan_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _currentPin = '1515';
  List<LoanModel> _allLoans = [];
  bool _isCloudSyncing = false;
  String _selectedFrequency = 'Diario';
  DateTime? _lastBackupDate;

  final List<String> _frequencyOptions = [
    'Diario',
    'Cada 3 días',
    'Semanal',
    'Cada 20 días',
    'Manual',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final pin = await SecurityService.instance.getPin();
    final loans = await DatabaseHelper.instance.getAllLoans();
    final freq = await FirebaseSyncService.instance.getAutoBackupFrequency();
    final lastDate = await FirebaseSyncService.instance.getLastBackupDate();

    setState(() {
      _currentPin = pin;
      _allLoans = loans;
      _selectedFrequency = freq;
      _lastBackupDate = lastDate;
    });

    FirebaseSyncService.instance.checkAndRunAutoBackup(loans).then((ran) {
      if (ran && mounted) _loadData();
    });
  }

  Future<void> _onFrequencyChanged(String? newFreq) async {
    if (newFreq == null) return;
    await FirebaseSyncService.instance.saveAutoBackupFrequency(newFreq);
    setState(() => _selectedFrequency = newFreq);
    _showSnackBar('Frecuencia de respaldo cambiada a: $newFreq ⏱️');
  }

  Future<void> _handleBackup(String choice) async {
    // Cargar siempre la lista fresca y actualizada desde la base de datos
    final currentLoans = await DatabaseHelper.instance.getAllLoans();

    if (currentLoans.isEmpty && (choice == 'export_json' || choice == 'export_csv' || choice == 'cloud_backup')) {
      _showSnackBar('No hay registros para procesar. Agrega al menos 1 préstamo.', isError: true);
      return;
    }

    if (choice == 'export_json') {
      final success = await BackupService.instance.exportJson(currentLoans);
      if (success) _showSnackBar('Respaldo JSON listo 🛡️');
    } else if (choice == 'export_csv') {
      final success = await BackupService.instance.exportCsv(currentLoans);
      if (success) _showSnackBar('Reporte Excel (CSV) listo 📊');
    } else if (choice == 'import_json') {
      try {
        final count = await BackupService.instance.importJson();
        if (count != null) {
          _showSnackBar('Se restauraron $count préstamos con éxito 🔄');
          _loadData();
        }
      } catch (e) {
        _showSnackBar('Error al restaurar respaldo: Archivo no válido', isError: true);
      }
    } else if (choice == 'cloud_backup') {
      setState(() => _isCloudSyncing = true);
      final success = await FirebaseSyncService.instance.backupToCloud(currentLoans);
      setState(() => _isCloudSyncing = false);
      if (success) {
        _showSnackBar('☁️ Copia de seguridad guardada en Firebase Nube');
        _loadData();
      } else {
        _showSnackBar('Respaldo de ${currentLoans.length} préstamo(s) listo para sincronizar a nube.');
      }
    } else if (choice == 'cloud_restore') {
      setState(() => _isCloudSyncing = true);
      final cloudLoans = await FirebaseSyncService.instance.restoreFromCloud();
      setState(() => _isCloudSyncing = false);

      if (cloudLoans != null && cloudLoans.isNotEmpty) {
        await DatabaseHelper.instance.replaceAllLoans(cloudLoans);
        _showSnackBar('☁️ Se restauraron ${cloudLoans.length} préstamos desde la Nube');
        _loadData();
      } else {
        _showSnackBar('No se encontró respaldo en la nube o falta configurar el archivo de Firebase', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.danger : AppTheme.primaryAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _changePinModal() {
    final pinController = TextEditingController(text: _currentPin);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Cambiar PIN de Acceso', style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ingresa tu nuevo PIN de 4 dígitos:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(hintText: '1515'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPin = pinController.text.trim();
              if (newPin.length == 4) {
                await SecurityService.instance.savePin(newPin);
                if (!mounted) return;
                Navigator.pop(ctx);
                _showSnackBar('PIN de acceso actualizado');
                _loadData();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent),
            child: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastBackupStr = _lastBackupDate != null
        ? '${AppFormatters.formatDate(_lastBackupDate!)} ${TimeOfDay.fromDateTime(_lastBackupDate!).format(context)}'
        : 'Sin respaldos registrados aún';

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline_rounded, color: AppTheme.primaryAccent),
            SizedBox(width: 8),
            Text('Perfil y Ajustes', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TARJETA PERFIL ADMINISTRADOR
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppTheme.primaryAccent.withValues(alpha: 0.2),
                    child: const Icon(Icons.shield_rounded, color: AppTheme.primaryAccent, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Administrador de Cobros', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text('PIN de Seguridad: $_currentPin', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // CONFIGURACIÓN DE RESPALDO AUTOMÁTICO
            const Text('☁️ Respaldo Automático en Nube', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Frecuencia de Respaldo', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                            SizedBox(height: 2),
                            Text('¿Cada cuánto deseas guardar copia?', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.4)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedFrequency,
                            dropdownColor: AppTheme.cardBg,
                            style: const TextStyle(color: AppTheme.primaryAccent, fontWeight: FontWeight.bold, fontSize: 12.5),
                            items: _frequencyOptions.map((opt) {
                              return DropdownMenuItem(value: opt, child: Text(opt));
                            }).toList(),
                            onChanged: _onFrequencyChanged,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 20),
                  Row(
                    children: [
                      const Icon(Icons.history_rounded, size: 15, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Última copia en nube: $lastBackupStr',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // SECCIÓN RESPALDOS Y FIREBASE NUBE
            const Text('🛡️ Opciones de Guardado y Restauración', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ListTile(
                    onTap: () => _handleBackup('cloud_backup'),
                    leading: _isCloudSyncing
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryAccent))
                        : const Icon(Icons.cloud_upload_rounded, color: Color(0xFF06B6D4)),
                    title: const Text('Respaldo Manual en Firebase Nube', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Subir copia instantánea a Firebase', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textSecondary),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  ListTile(
                    onTap: () => _handleBackup('cloud_restore'),
                    leading: const Icon(Icons.cloud_download_rounded, color: AppTheme.success),
                    title: const Text('Restaurar desde Firebase Nube', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                    subtitle: const Text('Recupera tus préstamos guardados', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textSecondary),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  ListTile(
                    onTap: () => _handleBackup('export_json'),
                    leading: const Icon(Icons.download_rounded, color: AppTheme.primaryAccent),
                    title: const Text('Exportar Respaldo Local (JSON)', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                    subtitle: const Text('Guarda un archivo de copia en tu celular', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textSecondary),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  ListTile(
                    onTap: () => _handleBackup('export_csv'),
                    leading: const Icon(Icons.table_chart_outlined, color: AppTheme.success),
                    title: const Text('Exportar a Excel (CSV)', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                    subtitle: const Text('Descarga un reporte en hoja de cálculo', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // SECCIÓN AJUSTES DE PIN
            const Text('🔐 Bloqueo y Seguridad', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ListTile(
                    onTap: _changePinModal,
                    leading: const Icon(Icons.lock_reset_rounded, color: AppTheme.primaryAccent),
                    title: const Text('Cambiar PIN de Acceso', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                    subtitle: Text('PIN actual: $_currentPin', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11.5)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // SECCIÓN FUTURAS FUNCIONALIDADES
            const Text('🚀 Futuras Funcionalidades', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.2)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Proximamente en esta sección:', style: TextStyle(color: AppTheme.primaryAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                  SizedBox(height: 6),
                  Text('• Gestión y directorio de clientes prestatarios', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  Text('• Impresión de recibos y exportación en PDF', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
