import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/services/reminder_preferences.dart';
import '../../transactions/domain/finance_models.dart';
import '../domain/reminder_plan.dart';

class ReminderStatus {
  const ReminderStatus({
    this.enabled = false,
    this.message = 'Ative os lembretes do aparelho.',
    this.scheduledDays = 0,
    this.coveredUntil,
  });
  final bool enabled;
  final String message;
  final int scheduledDays;
  final DateTime? coveredUntil;
}

abstract class ReminderService {
  ValueNotifier<ReminderStatus> get status;
  ValueNotifier<bool> get openRequested;
  Future<void> initialize();
  Future<void> activateOwner(String owner);
  Future<bool> requestPermission();
  Future<void> sync(String owner, List<FinanceEntry> entries);
  Future<List<FinanceEntry>?> cachedEntries(String owner);
  Future<void> clear();
}

class LocalReminderService implements ReminderService {
  final _plugin = FlutterLocalNotificationsPlugin();
  @override
  final status = ValueNotifier(const ReminderStatus());
  @override
  final openRequested = ValueNotifier(false);
  Future<void>? _initialization;
  Future<void> _queue = Future.value();
  SharedPreferences? _preferences;
  String? _owner;
  int _generation = 0;
  static const _cacheKey = 'financafacil.reminder_snapshot';
  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (!_supported) {
      status.value = const ReminderStatus(
        message: 'Lembretes do aparelho disponíveis no Android e iOS.',
      );
      return;
    }
    try {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(
        tz.getLocation(await FlutterTimezone.getLocalTimezone()),
      );
      _preferences = await SharedPreferences.getInstance();
      final saved = _preferences!.getString(_cacheKey);
      if (saved != null) {
        try {
          _owner = (jsonDecode(saved) as Map)['owner'] as String?;
        } catch (_) {
          await _preferences!.remove(_cacheKey);
        }
      }
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_reminder'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (_) => openRequested.value = true,
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) openRequested.value = true;
      final enabled = await _isEnabled();
      status.value = ReminderStatus(
        enabled: enabled,
        message: enabled
            ? 'Lembretes ativados no aparelho.'
            : 'Ative os lembretes do aparelho.',
      );
    } catch (_) {
      _initialization = null;
      status.value = const ReminderStatus(
        message: 'Não foi possível preparar os lembretes. Tente ativá-los novamente.',
      );
      rethrow;
    }
  }

  Future<bool> _isEnabled() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.areNotificationsEnabled() ??
          false;
    }
    return (await _plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.checkPermissions())
            ?.isEnabled ??
        false;
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _queue.catchError((Object _) {}).then((_) => action());
    _queue = next;
    return next;
  }

  @override
  Future<void> activateOwner(String owner) async {
    await initialize();
    if (_owner == owner) return;
    _owner = owner;
    _generation++;
    await _enqueue(() async {
      if (_supported) await _plugin.cancelAll();
      await _preferences?.remove(_cacheKey);
    });
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    if (!_supported) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } else {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, sound: true, badge: false);
    }
    final enabled = await _isEnabled();
    status.value = ReminderStatus(
      enabled: enabled,
      message: enabled
          ? 'Lembretes ativados. Preparando próximos vencimentos.'
          : 'Notificações bloqueadas. Você pode permitir nas configurações do aparelho.',
    );
    return enabled;
  }

  @override
  Future<void> sync(String owner, List<FinanceEntry> entries) async {
    await initialize();
    if (!_supported || owner != _owner) return;
    final generation = _generation;
    await _enqueue(() async {
      if (generation != _generation) return;
      await _preferences!.setString(
        _cacheKey,
        jsonEncode({
          'owner': owner,
          'entries': entries
              .map(
                (entry) => {
                  'id': entry.id,
                  'type': entry.kind.databaseValue,
                  'amount': entry.amount,
                  'description': entry.description,
                  'notes': entry.notes,
                  'due_date': entry.dueDate?.toIso8601String(),
                  'category': {'name': entry.categoryName},
                  'is_paid': entry.isPaid,
                  'is_recurrent': entry.isRecurring,
                  '_installment': entry.installment,
                  '_total_installments': entry.totalInstallments,
                  '_last_due': entry.lastDue?.toIso8601String(),
                },
              )
              .toList(),
        }),
      );
      if (generation != _generation) return;
      final enabled = await _isEnabled();
      if (generation != _generation) return;
      await _plugin.cancelAll();
      if (!enabled) {
        status.value = const ReminderStatus(
          message:
              'Ative as notificações para receber lembretes com o app fechado.',
        );
        return;
      }
      final plan = planReminders(
        entries,
        DateTime.now(),
        hour: ReminderPreferences.time.value.hour,
        minute: ReminderPreferences.time.value.minute,
      );
      try {
        for (final reminder in plan) {
          if (generation != _generation) return;
          await _plugin.zonedSchedule(
            reminder.id,
            'FinançaFácil • contas pendentes',
            '${reminder.count} conta(s) aguardam confirmação. Abra a lista de notificações.',
            tz.TZDateTime.from(reminder.date, tz.local),
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'bill_reminders_v1',
                'Lembretes de contas',
                channelDescription: 'Contas a vencer e pagamentos pendentes',
                importance: Importance.high,
                priority: Priority.high,
                icon: 'ic_stat_reminder',
              ),
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentSound: true,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: 'notifications',
          );
        }
        if (generation != _generation) return;
        status.value = ReminderStatus(
          enabled: true,
          scheduledDays: plan.length,
          coveredUntil: plan.isEmpty ? null : plan.last.date,
          message: plan.isEmpty
              ? 'Sem contas pendentes para lembrar nos próximos 90 dias.'
              : 'Lembretes preparados. Abra o app periodicamente para renovar os próximos vencimentos.',
        );
      } catch (_) {
        status.value = const ReminderStatus(
          enabled: true,
          message: 'Alguns lembretes não foram preparados. Abra o app e tente novamente.',
        );
        rethrow;
      }
    });
  }

  @override
  Future<List<FinanceEntry>?> cachedEntries(String owner) async {
    await initialize();
    final saved = _preferences?.getString(_cacheKey);
    if (saved == null) return null;
    try {
      final data = jsonDecode(saved) as Map;
      if (data['owner'] != owner) return null;
      return (data['entries'] as List)
          .map(
            (entry) =>
                FinanceEntry.fromMap(Map<String, dynamic>.from(entry as Map)),
          )
          .toList();
    } catch (_) {
      await _preferences?.remove(_cacheKey);
      return null;
    }
  }

  @override
  Future<void> clear() async {
    _generation++;
    _owner = null;
    openRequested.value = false;
    await _enqueue(() async {
      if (_supported && _preferences != null) await _plugin.cancelAll();
      await _preferences?.remove(_cacheKey);
      status.value = const ReminderStatus();
    });
  }
}
