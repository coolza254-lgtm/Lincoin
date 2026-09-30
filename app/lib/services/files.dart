import 'dart:io';

import 'package:crypto/crypto.dart';

/// Hex SHA-256 of a file, streamed (content packs can be tens of MB).
Future<String> sha256OfFile(File f) async =>
    (await sha256.bind(f.openRead()).first).toString();

/// App directories, created on start.
class AppPaths {
  final Directory root;
  AppPaths(this.root);

  String get userDb => '${root.path}/user.db';
  Directory get content => Directory('${root.path}/content');
  Directory get backups => Directory('${root.path}/backups');
  Directory get downloads => Directory('${root.path}/downloads');
  Directory get tmp => Directory('${root.path}/tmp');

  void ensure() {
    for (final d in [content, backups, downloads, tmp]) {
      d.createSync(recursive: true);
    }
  }
}
