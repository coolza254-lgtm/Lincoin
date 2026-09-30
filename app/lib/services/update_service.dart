import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../data/content_db.dart';
import 'files.dart';

/// Public repository the app updates from (docs/10-updates.md, option A).
const updateRepo = 'coolza254-lgtm/Lincoin';
const latestManifestUrl =
    'https://github.com/$updateRepo/releases/latest/download/latest.json';

class AppRelease {
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String sha256;
  final int sizeBytes;
  final int minAndroidSdk;
  final List<String> changelogTh;

  const AppRelease({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.sha256,
    required this.sizeBytes,
    required this.minAndroidSdk,
    required this.changelogTh,
  });

  factory AppRelease.fromJson(Map<String, dynamic> j) => AppRelease(
    versionCode: (j['versionCode'] as num).toInt(),
    versionName: j['versionName'] as String,
    apkUrl: j['apkUrl'] as String,
    sha256: j['sha256'] as String,
    sizeBytes: (j['sizeBytes'] as num).toInt(),
    minAndroidSdk: (j['minAndroidSdk'] as num?)?.toInt() ?? 24,
    changelogTh: ((j['changelogTh'] as List?) ?? const []).cast<String>(),
  );
}

class ContentRelease {
  final String version;
  final String url;
  final String sha256;
  final int sizeBytes;
  final int minAppVersionCode;
  final List<String> changelogTh;

  const ContentRelease({
    required this.version,
    required this.url,
    required this.sha256,
    required this.sizeBytes,
    required this.minAppVersionCode,
    required this.changelogTh,
  });

  factory ContentRelease.fromJson(Map<String, dynamic> j) => ContentRelease(
    version: j['version'] as String,
    url: j['url'] as String,
    sha256: j['sha256'] as String,
    sizeBytes: (j['sizeBytes'] as num).toInt(),
    minAppVersionCode: (j['minAppVersionCode'] as num?)?.toInt() ?? 0,
    changelogTh: ((j['changelogTh'] as List?) ?? const []).cast<String>(),
  );
}

class LatestManifest {
  final AppRelease? app;
  final ContentRelease? content;
  const LatestManifest(this.app, this.content);

  factory LatestManifest.fromJson(Map<String, dynamic> j) => LatestManifest(
    j['app'] == null
        ? null
        : AppRelease.fromJson(j['app'] as Map<String, dynamic>),
    j['content'] == null
        ? null
        : ContentRelease.fromJson(j['content'] as Map<String, dynamic>),
  );
}

/// What is newer than what is installed.
class UpdateCheck {
  final LatestManifest manifest;
  final AppRelease? appUpdate;
  final ContentRelease? contentUpdate;

  /// Newer content exists but needs a newer app first.
  final bool contentNeedsNewerApp;
  final DateTime checkedAtUtc;

  const UpdateCheck({
    required this.manifest,
    required this.appUpdate,
    required this.contentUpdate,
    required this.contentNeedsNewerApp,
    required this.checkedAtUtc,
  });

  bool get hasAny => appUpdate != null || contentUpdate != null;
}

class UpdateException implements Exception {
  final String messageTh;
  const UpdateException(this.messageTh);
  @override
  String toString() => messageTh;
}

UpdateCheck compareWithInstalled(
  LatestManifest m, {
  required int appVersionCode,
  required String? contentVersion,
  required DateTime nowUtc,
}) {
  final app = m.app != null && m.app!.versionCode > appVersionCode
      ? m.app
      : null;
  final c = m.content;
  final newerContent =
      c != null &&
      (contentVersion == null ||
          compareVersions(c.version, contentVersion) > 0);
  final supported = c != null && c.minAppVersionCode <= appVersionCode;
  return UpdateCheck(
    manifest: m,
    appUpdate: app,
    contentUpdate: newerContent && supported ? c : null,
    contentNeedsNewerApp: newerContent && !supported,
    checkedAtUtc: nowUtc,
  );
}

/// Online update checks and downloads (HTTPS, sha256 verified).
class UpdateService {
  final http.Client client;
  final Uri manifestUri;
  UpdateService(this.client, {Uri? manifestUri})
    : manifestUri = manifestUri ?? Uri.parse(latestManifestUrl);

  Future<LatestManifest> fetchLatest() async {
    final http.Response r;
    try {
      r = await client
          .get(manifestUri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
    } on SocketException {
      throw const UpdateException(
        'ต่อเน็ตไม่ได้ ลองใหม่ภายหลัง หรือใช้ "อัปเดตจากไฟล์"',
      );
    } on TimeoutException {
      throw const UpdateException('เชื่อมต่อนานเกินไป ลองใหม่ภายหลัง');
    } on http.ClientException {
      throw const UpdateException(
        'ต่อเน็ตไม่ได้ ลองใหม่ภายหลัง หรือใช้ "อัปเดตจากไฟล์"',
      );
    }
    if (r.statusCode == 404) {
      throw const UpdateException('ยังไม่มีเวอร์ชันที่เผยแพร่');
    }
    if (r.statusCode != 200) {
      throw UpdateException('เซิร์ฟเวอร์ตอบกลับ ${r.statusCode}');
    }
    try {
      return LatestManifest.fromJson(
        jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>,
      );
    } on Object {
      throw const UpdateException('ข้อมูลอัปเดตอ่านไม่ได้');
    }
  }

  /// Downloads [url] to [target], resuming a partial `.part` file, then
  /// checks sha256. A mismatch deletes the file and throws.
  Future<File> download(
    String url,
    File target, {
    required String sha256,
    int? sizeBytes,
    void Function(int received, int? total)? onProgress,
  }) async {
    if (!url.startsWith('https://')) {
      throw const UpdateException('ลิงก์ดาวน์โหลดไม่ปลอดภัย (ไม่ใช่ HTTPS)');
    }
    // Already downloaded (e.g. the install was postponed): reuse it.
    if (target.existsSync() &&
        (await sha256OfFile(target)).toLowerCase() == sha256.toLowerCase()) {
      return target;
    }
    final part = File('${target.path}.part');
    var have = part.existsSync() ? part.lengthSync() : 0;
    final req = http.Request('GET', Uri.parse(url));
    if (have > 0) req.headers['Range'] = 'bytes=$have-';
    final http.StreamedResponse res;
    try {
      res = await client.send(req).timeout(const Duration(seconds: 30));
    } on Object {
      throw const UpdateException('ดาวน์โหลดไม่สำเร็จ ลองใหม่อีกครั้ง');
    }
    if (res.statusCode == 200) {
      have = 0; // server ignored Range: start over
    } else if (res.statusCode != 206) {
      throw UpdateException('ดาวน์โหลดไม่สำเร็จ (${res.statusCode})');
    }
    final total =
        sizeBytes ??
        (res.contentLength == null ? null : res.contentLength! + have);
    final sink = part.openWrite(
      mode: have > 0 ? FileMode.append : FileMode.write,
    );
    var received = have;
    try {
      await for (final chunk in res.stream.timeout(
        const Duration(seconds: 60),
      )) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
    } on Object {
      await sink.close();
      throw const UpdateException(
        'เน็ตหลุดระหว่างดาวน์โหลด กดอีกครั้งเพื่อต่อจากเดิม',
      );
    }
    await sink.close();
    final actual = await sha256OfFile(part);
    if (actual.toLowerCase() != sha256.toLowerCase()) {
      part.deleteSync();
      throw const UpdateException(
        'ไฟล์ที่ดาวน์โหลดไม่ถูกต้อง (sha256 ไม่ตรง) ลบแล้ว',
      );
    }
    if (target.existsSync()) target.deleteSync();
    return part.renameSync(target.path);
  }
}
