import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/constants/app_theme.dart';
import 'core/services/notification_service.dart';
import 'screens/pin_lock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bloquear orientación en vertical para mejor usabilidad
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Inicializar formato de fechas en español
  await initializeDateFormatting('es', null);

  // Inicializar notificaciones locales
  await NotificationService.instance.init();

  runApp(const ProyectoCobroApp());
}

class ProyectoCobroApp extends StatelessWidget {
  const ProyectoCobroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Control de Préstamos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const PinLockScreen(),
    );
  }
}
