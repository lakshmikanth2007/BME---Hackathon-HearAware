import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../models/detection.dart';
import '../models/user_profile.dart';

class AppSettings {
  const AppSettings({this.backend = AppConstants.defaultBackend, this.speechRate = 0.5, this.flash = true});
  final String backend;
  final double speechRate;
  final bool flash;

  AppSettings copyWith({String? backend, double? speechRate, bool? flash}) => AppSettings(
        backend: backend ?? this.backend,
        speechRate: speechRate ?? this.speechRate,
        flash: flash ?? this.flash,
      );
}

/// Local persistence (profile, settings, last events). Text only - never raw media.
class SettingsStore {
  SettingsStore(this._p);
  final SharedPreferences _p;

  UserProfile? get profile => UserProfile.fromName(_p.getString('profile'));
  Future<void> saveProfile(UserProfile p) => _p.setString('profile', p.name);

  AppSettings loadSettings() => AppSettings(
        backend: _p.getString('backend') ?? AppConstants.defaultBackend,
        speechRate: _p.getDouble('speechRate') ?? 0.5,
        flash: _p.getBool('flash') ?? true,
      );

  Future<void> saveSettings(AppSettings s) async {
    await _p.setString('backend', s.backend);
    await _p.setDouble('speechRate', s.speechRate);
    await _p.setBool('flash', s.flash);
  }

  List<Alert> loadHistory() {
    try {
      final raw = _p.getString('history');
      if (raw == null) return [];
      return (jsonDecode(raw) as List).map((e) => Alert.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHistory(List<Alert> h) =>
      _p.setString('history', jsonEncode(h.take(AppConstants.historyLimit).map((a) => a.toJson()).toList()));
}
