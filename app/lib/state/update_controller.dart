import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/content_db.dart';
import '../services/app_installer.dart';
import '../services/content_pack.dart';
import '../services/update_service.dart';
import 'providers.dart';

const _lastCheckKey = 'update.last_check';
const _appId = 'io.github.coolza254.lincoin';

class UpdateUiState {
  final bool busy;
  final UpdateCheck? check;
  final String? error;

  /// What is running now (download, install …).
  final String? busyLabel;
  final double? progress;
  final DateTime? lastCheckedUtc;

  const UpdateUiState({
    this.busy = false,
    this.check,
    this.error,
    this.busyLabel,
    this.progress,
    this.lastCheckedUtc,
  });

  bool get hasUpdate => check?.hasAny ?? false;

  UpdateUiState copyWith({
    bool? busy,
    UpdateCheck? check,
    String? error,
    String? busyLabel,
    double? progress,
    DateTime? lastCheckedUtc,
    bool clearError = false,
    bool clearBusy = false,
  }) => UpdateUiState(
    busy: busy ?? this.busy,
    check: check ?? this.check,
    error: clearError ? null : (error ?? this.error),
    busyLabel: clearBusy ? null : (busyLabel ?? this.busyLabel),
    progress: clearBusy ? null : (progress ?? this.progress),
    lastCheckedUtc: lastCheckedUtc ?? this.lastCheckedUtc,
  );
}

/// A picked file, checked and waiting for the learner to confirm.
sealed class FileUpdate {
  const FileUpdate();
}

class ApkFileUpdate extends FileUpdate {
  final File file;
  final ApkInfo info;
  const ApkFileUpdate(this.file, this.info);
}

class ContentFileUpdate extends FileUpdate {
  final ExtractedPack pack;
  final String? installedVersion;
  const ContentFileUpdate(this.pack, this.installedVersion);
}

/// Result of an action, shown as a message.
class UpdateOutcome {
  final bool ok;
  final String messageTh;
  const UpdateOutcome(this.ok, this.messageTh);
}

/// The two buttons in Settings → Updates (docs/10-updates.md): online check
/// against GitHub Releases, and install from a local file. Both back up the
/// user database first and never install without a confirmation.
class UpdateController extends Notifier<UpdateUiState> {
  final installer = AppInstaller();

  @override
  UpdateUiState build() {
    final sub = installer.events.listen(_onInstallEvent);
    ref.onDispose(sub.cancel);
    final db = ref.read(userDbProvider);
    final last = db.meta(_lastCheckKey);
    return UpdateUiState(
      lastCheckedUtc: last == null ? null : DateTime.tryParse(last),
    );
  }

  int get _appCode => ref.read(appVersionProvider).code;
  String? get _contentVersion => ref.read(catalogProvider)?.info.version;

  /// Online check. Returns an error message, or null.
  Future<String?> check() async {
    if (!ref.read(settingsProvider).onlineUpdateCheck) {
      return 'ปิดการตรวจอัปเดตออนไลน์อยู่ เปิดได้ในหน้านี้ หรือใช้ "อัปเดตจากไฟล์"';
    }
    state = state.copyWith(
      busy: true,
      clearError: true,
      busyLabel: 'กำลังตรวจ…',
    );
    try {
      final m = await ref.read(updateServiceProvider).fetchLatest();
      final now = DateTime.now().toUtc();
      ref.read(userDbProvider).setMeta(_lastCheckKey, now.toIso8601String());
      state = UpdateUiState(
        check: compareWithInstalled(
          m,
          appVersionCode: _appCode,
          contentVersion: _contentVersion,
          nowUtc: now,
        ),
        lastCheckedUtc: now,
      );
      return null;
    } on UpdateException catch (e) {
      state = state.copyWith(busy: false, error: e.messageTh, clearBusy: true);
      return e.messageTh;
    }
  }

  /// Once a day at most, silently; only shows a dot when something is new.
  Future<void> autoCheck() async {
    if (!ref.read(settingsProvider).onlineUpdateCheck) return;
    final last = state.lastCheckedUtc;
    if (last != null &&
        DateTime.now().toUtc().difference(last) < const Duration(hours: 24)) {
      return;
    }
    await check();
  }

  void _progress(String label, int received, int? total) {
    state = state.copyWith(
      busy: true,
      busyLabel: label,
      progress: total == null || total == 0 ? null : received / total,
    );
  }

  void _backup(String reason) =>
      ref.read(backupServiceProvider).backup(ref.read(userDbProvider), reason);

  Future<UpdateOutcome> installApp(AppRelease r) async {
    try {
      _backup('before_update');
      final dir = ref.read(pathsProvider).downloads;
      final file = await ref
          .read(updateServiceProvider)
          .download(
            r.apkUrl,
            File('${dir.path}/lincoin-${r.versionName}.apk'),
            sha256: r.sha256,
            sizeBytes: r.sizeBytes,
            onProgress: (a, b) => _progress('ดาวน์โหลดแอป', a, b),
          );
      return await _installApk(file);
    } on UpdateException catch (e) {
      return UpdateOutcome(false, e.messageTh);
    } finally {
      state = state.copyWith(busy: false, clearBusy: true);
    }
  }

  Future<UpdateOutcome> _installApk(File file) async {
    if (!await installer.canInstall()) {
      await installer.openInstallPermission();
      return const UpdateOutcome(
        false,
        'อนุญาต "ติดตั้งแอปที่ไม่รู้จัก" ให้ Lincoin แล้วกดอัปเดตอีกครั้ง (ไฟล์ดาวน์โหลดไว้แล้ว)',
      );
    }
    state = state.copyWith(busy: true, busyLabel: 'กำลังติดตั้ง…');
    try {
      await installer.install(file.path);
    } on PlatformException catch (e) {
      return UpdateOutcome(false, 'ติดตั้งไม่สำเร็จ: ${e.message ?? e.code}');
    }
    return const UpdateOutcome(
      true,
      'กำลังติดตั้ง แอปจะปิดตัวแล้วเปลี่ยนเป็นเวอร์ชันใหม่ '
      '(ถ้า Android ถาม ให้กด "อัปเดต")',
    );
  }

  void _onInstallEvent(InstallEvent e) {
    final msg = switch (e.status) {
      InstallStatus.confirm || InstallStatus.success => null,
      InstallStatus.aborted => 'ยกเลิกการอัปเดตแล้ว',
      InstallStatus.conflict =>
        'ติดตั้งทับไม่ได้: ไฟล์นี้เซ็นด้วยกุญแจคนละชุดกับแอปที่ติดตั้งอยู่',
      InstallStatus.storage => 'พื้นที่ในเครื่องไม่พอสำหรับอัปเดต',
      InstallStatus.failed =>
        'ติดตั้งไม่สำเร็จ${e.message == null ? '' : ': ${e.message}'}',
    };
    if (msg != null) state = state.copyWith(error: msg);
  }

  Future<UpdateOutcome> installContent(ContentRelease r) async {
    final paths = ref.read(pathsProvider);
    try {
      final file = await ref
          .read(updateServiceProvider)
          .download(
            r.url,
            File(
              '${paths.downloads.path}/content-${r.version}.lincoin-content',
            ),
            sha256: r.sha256,
            sizeBytes: r.sizeBytes,
            onProgress: (a, b) => _progress('ดาวน์โหลดเนื้อหา', a, b),
          );
      final pack = await extractContentPack(file, paths.tmp);
      final res = await _applyContent(pack);
      file.deleteSync();
      return res;
    } on UpdateException catch (e) {
      return UpdateOutcome(false, e.messageTh);
    } on ContentPackException catch (e) {
      return UpdateOutcome(false, e.messageTh);
    } finally {
      state = state.copyWith(busy: false, clearBusy: true);
    }
  }

  Future<UpdateOutcome> _applyContent(ExtractedPack pack) async {
    if (pack.manifest.minAppVersionCode > _appCode) {
      return const UpdateOutcome(
        false,
        'เนื้อหานี้ต้องใช้แอปเวอร์ชันใหม่กว่า กรุณาอัปเดตแอปก่อน',
      );
    }
    state = state.copyWith(busy: true, busyLabel: 'กำลังติดตั้งเนื้อหา');
    _backup('before_content');
    final res = await ref
        .read(contentStoreProvider)
        .install(pack.db, expectedSha256: pack.manifest.sha256);
    if (pack.db.existsSync()) pack.db.deleteSync();
    if (!res.ok) return UpdateOutcome(false, res.problems.join('\n'));
    ref.read(catalogProvider.notifier).reload();
    final c = state.check;
    if (c != null) {
      state = state.copyWith(
        check: compareWithInstalled(
          c.manifest,
          appVersionCode: _appCode,
          contentVersion: res.version,
          nowUtc: c.checkedAtUtc,
        ),
      );
    }
    return UpdateOutcome(true, 'ติดตั้งเนื้อหาเวอร์ชัน ${res.version} แล้ว');
  }

  /// "อัปเดตจากไฟล์": pick a file and check it. Returns null when the
  /// picker was cancelled; throws [UpdateException] for an unusable file.
  Future<FileUpdate?> pickFile() async {
    final picked = await FilePicker.pickFiles();
    if (picked.isEmpty) return null;
    final f = picked.first;
    final name = f.name.toLowerCase();
    final paths = ref.read(pathsProvider);
    state = state.copyWith(busy: true, busyLabel: 'กำลังอ่านไฟล์');
    try {
      if (name.endsWith('.apk')) {
        final dest = File('${paths.downloads.path}/picked.apk');
        await _copy(f, dest);
        final info = await installer.apkInfo(dest.path);
        if (info == null) throw const UpdateException('อ่านไฟล์ APK ไม่ได้');
        if (info.packageName != _appId) {
          throw const UpdateException('ไฟล์นี้ไม่ใช่แอป Lincoin');
        }
        if (info.versionCode <= _appCode) {
          throw UpdateException(
            'ไฟล์นี้เป็นเวอร์ชัน ${info.versionName} ไม่ใหม่กว่าที่ติดตั้งอยู่',
          );
        }
        return ApkFileUpdate(dest, info);
      }
      if (name.endsWith('.lincoin-content') || name.endsWith('.zip')) {
        final dest = File('${paths.tmp.path}/picked.lincoin-content');
        await _copy(f, dest);
        try {
          final pack = await extractContentPack(dest, paths.tmp);
          final installed = _contentVersion;
          if (installed != null &&
              compareVersions(pack.manifest.version, installed) <= 0) {
            throw UpdateException(
              'เนื้อหาในไฟล์ (${pack.manifest.version}) '
              'ไม่ใหม่กว่าที่ติดตั้งอยู่ ($installed)',
            );
          }
          return ContentFileUpdate(pack, installed);
        } on ContentPackException catch (e) {
          throw UpdateException(e.messageTh);
        } finally {
          dest.deleteSync();
        }
      }
      throw const UpdateException(
        'รองรับไฟล์ .apk (แอป) และ .lincoin-content (เนื้อหา) เท่านั้น',
      );
    } finally {
      state = state.copyWith(busy: false, clearBusy: true);
    }
  }

  Future<UpdateOutcome> applyFile(FileUpdate u) async {
    try {
      switch (u) {
        case ApkFileUpdate():
          _backup('before_update');
          return await _installApk(u.file);
        case ContentFileUpdate():
          return await _applyContent(u.pack);
      }
    } finally {
      state = state.copyWith(busy: false, clearBusy: true);
    }
  }

  /// Switches back to the previous content version.
  UpdateOutcome rollbackContent() {
    _backup('before_content');
    if (!ref.read(contentStoreProvider).rollback()) {
      return const UpdateOutcome(false, 'ไม่มีเวอร์ชันก่อนหน้าให้ย้อนกลับ');
    }
    ref.read(catalogProvider.notifier).reload();
    return UpdateOutcome(
      true,
      'ย้อนกลับเป็นเนื้อหาเวอร์ชัน $_contentVersion แล้ว',
    );
  }

  static Future<void> _copy(PlatformFile f, File dest) async {
    if (dest.existsSync()) dest.deleteSync();
    final sink = dest.openWrite();
    await sink.addStream(f.readAsByteStream());
    await sink.close();
  }
}

final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateUiState>(UpdateController.new);
