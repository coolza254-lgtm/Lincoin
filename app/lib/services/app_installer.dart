import 'package:flutter/services.dart';

class ApkInfo {
  final String packageName;
  final int versionCode;
  final String versionName;
  const ApkInfo(this.packageName, this.versionCode, this.versionName);
}

/// Hands an APK to Android's package installer (see MainActivity.kt).
/// Android itself checks that the signature matches the installed app.
class AppInstaller {
  static const _ch = MethodChannel('lincoin/installer');

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

  Future<void> install(String path) =>
      _ch.invokeMethod('install', {'path': path});
}
