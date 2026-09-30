import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

/// `.lincoin-content` file: a zip with `content.db` and `manifest.json`.
/// Built by tools/release/make_content_pack.py.
class ContentPackManifest {
  final int format;
  final String version;
  final int schemaVersion;
  final String sha256;
  final int minAppVersionCode;
  final List<String> changelogTh;

  const ContentPackManifest({
    required this.format,
    required this.version,
    required this.schemaVersion,
    required this.sha256,
    required this.minAppVersionCode,
    required this.changelogTh,
  });

  factory ContentPackManifest.fromJson(Map<String, dynamic> j) =>
      ContentPackManifest(
        format: (j['format'] as num?)?.toInt() ?? 1,
        version: j['version'] as String,
        schemaVersion: (j['schemaVersion'] as num).toInt(),
        sha256: j['sha256'] as String,
        minAppVersionCode: (j['minAppVersionCode'] as num?)?.toInt() ?? 0,
        changelogTh: ((j['changelogTh'] as List?) ?? const []).cast<String>(),
      );
}

class ExtractedPack {
  final ContentPackManifest manifest;
  final File db;
  const ExtractedPack(this.manifest, this.db);
}

class ContentPackException implements Exception {
  final String messageTh;
  const ContentPackException(this.messageTh);
  @override
  String toString() => messageTh;
}

/// Extracts [pack] into [tmpDir]. Checks happen afterwards in
/// ContentStore.install (sha256, schema, credits).
Future<ExtractedPack> extractContentPack(File pack, Directory tmpDir) async {
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(await pack.readAsBytes());
  } on Object {
    throw const ContentPackException(
      'ไฟล์นี้ไม่ใช่ชุดเนื้อหา Lincoin (อ่าน zip ไม่ได้)',
    );
  }
  final m = zip.findFile('manifest.json');
  final db = zip.findFile('content.db');
  if (m == null || db == null) {
    throw const ContentPackException(
      'ชุดเนื้อหาไม่ครบ (ต้องมี content.db และ manifest.json)',
    );
  }
  final ContentPackManifest manifest;
  try {
    manifest = ContentPackManifest.fromJson(
      jsonDecode(utf8.decode(m.readBytes()!)) as Map<String, dynamic>,
    );
  } on Object {
    throw const ContentPackException('manifest.json อ่านไม่ได้');
  }
  if (manifest.format != 1) {
    throw const ContentPackException(
      'รูปแบบชุดเนื้อหาใหม่กว่าที่แอปนี้รองรับ กรุณาอัปเดตแอป',
    );
  }
  tmpDir.createSync(recursive: true);
  final out = File('${tmpDir.path}/pack-${manifest.version}.db');
  await out.writeAsBytes(db.readBytes()!, flush: true);
  return ExtractedPack(manifest, out);
}
