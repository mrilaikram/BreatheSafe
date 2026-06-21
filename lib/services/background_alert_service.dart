import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/user_profile.dart';
import 'profile_service.dart';

class BackgroundAlertService {
  static const _channel = MethodChannel('breathe_safe/background_alerts');

  static Future<bool> configureFromProfile(ProfileService profileService) async {
    return await configure(
      enabled: profileService.backgroundAlertsEnabled,
      snoozeMinutes: profileService.alertSnoozeMinutes,
      profile: profileService.profile,
    );
  }

  static Future<bool> configure({
    required bool enabled,
    required int snoozeMinutes,
    required UserProfile profile,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;

    if (enabled) {
      await Permission.notification.request();
    }

    try {
      final result = await _channel.invokeMethod<bool>('configure', {
        'enabled': enabled,
        'snoozeMinutes': snoozeMinutes,
        'ageGroup': profile.ageGroup?.name ?? AgeGroup.adult.name,
        'conditions': profile.conditions.map((condition) {
          return condition.name;
        }).toList(),
      });
      return result ?? false;
    } catch (e) {
      debugPrint('Failed to configure background alerts: $e');
      return false;
    }
  }

  static Future<String?> getLastConnectedMac() async {
    try {
      return await _channel.invokeMethod<String>('getLastConnectedMac');
    } catch (e) {
      debugPrint('Failed to get last connected MAC: $e');
      return null;
    }
  }

  static Future<bool> getConnectionStatus() async {
    try {
      final result = await _channel.invokeMethod<bool>('getConnectionStatus');
      return result ?? false;
    } catch (e) {
      debugPrint('Failed to get connection status: $e');
      return false;
    }
  }

  static Future<void> stop() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    try {
      await _channel.invokeMethod<bool>('stop');
    } catch (error) {
      debugPrint('Background alert stop failed: $error');
    }
  }
}
