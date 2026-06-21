import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class ProfileService extends ChangeNotifier {
  static const String _ageGroupKey = 'age_group';
  static const String _conditionsKey = 'conditions';
  static const String _backgroundAlertsEnabledKey = 'background_alerts_enabled';
  static const String _alertSnoozeMinutesKey = 'alert_snooze_minutes';

  UserProfile _profile = const UserProfile();
  bool _backgroundAlertsEnabled = true;
  int _alertSnoozeMinutes = 15;
  bool _isInitialized = false;

  UserProfile get profile => _profile;
  bool get backgroundAlertsEnabled => _backgroundAlertsEnabled;
  int get alertSnoozeMinutes => _alertSnoozeMinutes;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    final ageStr = prefs.getString(_ageGroupKey);
    AgeGroup? age;
    if (ageStr != null) {
      age = AgeGroup.values.firstWhere(
        (e) => e.name == ageStr,
        orElse: () => AgeGroup.adult,
      );
    }

    final conditionsList = prefs.getStringList(_conditionsKey) ?? [];
    final conditions = conditionsList.map((c) {
      return RespiratoryCondition.values.firstWhere(
        (e) => e.name == c,
        orElse: () => RespiratoryCondition.none,
      );
    }).toSet();

    _profile = UserProfile(ageGroup: age, conditions: conditions);
    _backgroundAlertsEnabled =
        prefs.getBool(_backgroundAlertsEnabledKey) ?? true;
    _alertSnoozeMinutes = prefs.getInt(_alertSnoozeMinutesKey) ?? 15;
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> updateProfile(UserProfile newProfile) async {
    _profile = newProfile;
    final prefs = await SharedPreferences.getInstance();

    if (newProfile.ageGroup != null) {
      await prefs.setString(_ageGroupKey, newProfile.ageGroup!.name);
    }

    final conditionsList = newProfile.conditions.map((c) => c.name).toList();
    await prefs.setStringList(_conditionsKey, conditionsList);

    notifyListeners();
  }

  Future<void> updateBackgroundAlerts({
    bool? enabled,
    int? snoozeMinutes,
  }) async {
    if (enabled != null) {
      _backgroundAlertsEnabled = enabled;
    }

    if (snoozeMinutes != null) {
      _alertSnoozeMinutes = snoozeMinutes;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backgroundAlertsEnabledKey, _backgroundAlertsEnabled);
    await prefs.setInt(_alertSnoozeMinutesKey, _alertSnoozeMinutes);

    notifyListeners();
  }
}
