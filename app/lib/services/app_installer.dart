import 'dart:async';

import 'package:flutter/services.dart';

class ApkInfo {
  final String packageName;
  final int versionCode;
  final String versionName;
  const ApkInfo(this.packageName, this.versionCode, this.versionName);
}

/// Result reported by Android's package installer for a session.
enum InstallStatus { confirm, success, aborted, conflict, storage, failed }

class InstallEvent {
  final InstallStatus status;
  final String? message;
  const InstallEvent(this.status, this.message);
}

/// Installs a new APK over the running app with a PackageInstaller session
/// (see SelfUpdater.kt): the whole update happens inside Lincoin. Android
/// checks that the signature matches the installed app.
class AppInstaller {
  static const _ch = MethodChannel('lincoin/installer');
  static final _events = StreamController<InstallEvent>.broadcast();
  static bool _listening = false;

  AppInstaller() {
    if (_listening) return;
    _listening = true;
    _ch.setMethodCallHandler((call) async {
      if (call.method != 'installStatus') return;
      final args = Map<String, Object?>.from(call.arguments as Map);
      final status =
          InstallStatus.values
              .where((s) => s.name == args['status'])
              .firstOrNull ??
          InstallStatus.failed;
      _events.add(InstallEvent(status, args['message'] as String?));
    });
  }

  Stream<InstallEvent> get events => _events.stream;

  Future<ApkInfo?> apkInfo(String path) async {
    final m = await _ch.invokeMapMethod<String, Object?>('apkInfo', {
      'path': path,
    });
    if (m == null) return null;
    return ApkInfo(
      m['packageName'] as String,
      (m['versionCode'] as num).toInt(),
      (m['versionName'] as String?) ?? '',
    );
  }

  /// Whether "install unknown apps" is allowed for Lincoin.
  Future<bool> canInstall() async =>
      await _ch.invokeMethod<bool>('canInstall') ?? false;

  Future<void> openInstallPermission() =>
      _ch.invokeMethod('openInstallPermission');

  /// Starts the install; the result arrives on [events]. On success
  /// Android closes the app and replaces it.
  Future<void> install(String path) =>
      _ch.invokeMethod('install', {'path': path});
}
