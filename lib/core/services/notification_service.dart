import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../../models/loan_model.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  NotificationService._init();

  Future<void> init() async {
    if (_isInitialized || kIsWeb) return;

    try {
      tz.initializeTimeZones();

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(initSettings);
      _isInitialized = true;
    } catch (e) {
      print('Aviso: Notificaciones no disponibles en esta plataforma: $e');
    }
  }

  Future<void> scheduleLoanReminder(LoanModel loan) async {
    if (kIsWeb || !_isInitialized || loan.id == null) return;

    try {
      final dueDate = loan.dueDate;
      final scheduledTime = DateTime(dueDate.year, dueDate.month, dueDate.day, 9, 0);

      if (scheduledTime.isBefore(DateTime.now())) {
        return;
      }

      final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

      const androidDetails = AndroidNotificationDetails(
        'loan_reminders_channel',
        'Recordatorios de Cobro',
        channelDescription: 'Canal para alertas discretas de cobro',
        importance: Importance.max,
        priority: Priority.high,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      // Notificación discreta de privacidad: Oculta montos financieros
      await _notificationsPlugin.zonedSchedule(
        loan.id!,
        'Recordatorio Pendiente',
        '${loan.debtorName}: Ver asunto',
        tzScheduledTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      print('Error al programar notificación: $e');
    }
  }

  Future<void> cancelReminder(int loanId) async {
    if (kIsWeb || !_isInitialized) return;
    try {
      await _notificationsPlugin.cancel(loanId);
    } catch (e) {
      print('Error al cancelar notificación: $e');
    }
  }
}
