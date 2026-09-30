import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../ui/tokens.g.dart';
import '../../ui/widgets.dart';
import 'updates_screen.dart' show formatBytes;

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _export() async {
    final t = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final f = ref
          .read(backupServiceProvider)
          .backup(ref.read(userDbProvider), 'manual');
      final now = DateTime.now();
      final name =
          'lincoin-backup-${now.year}${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}.db';
      final uri = await FilePicker.saveFile(
        fileName: name,
        bytes: await f.readAsBytes(),
      );
      _snack(uri == null ? t.exportCancelled : t.exported);
    } on Object catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final t = AppLocalizations.of(context);
    final picked = await FilePicker.pickFiles();
    if (picked.isEmpty) return;
    final tmp = File('${ref.read(pathsProvider).tmp.path}/import.db');
    if (tmp.existsSync()) tmp.deleteSync();
    final sink = tmp.openWrite();
    await sink.addStream(picked.first.readAsByteStream());
    await sink.close();
    if (!mounted) return;
    if (!await _confirm(t.restoreConfirmTitle, t.restoreConfirmBody)) return;
    _restore(tmp.path);
    tmp.deleteSync();
  }

  void _restore(String path) {
    final t = AppLocalizations.of(context);
    final problems = ref.read(userDbProvider.notifier).restore(path);
    if (problems.isNotEmpty) {
      _snack(problems.join('\n'));
      return;
    }
    ref.read(dataVersionProvider.notifier).bump();
    _snack(t.restored);
    setState(() {});
  }

  Future<bool> _confirm(String title, String body) async {
    final t = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(t.confirm),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final backups = ref.watch(backupServiceProvider).list();
    return Scaffold(
      appBar: AppBar(title: Text(t.backup)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          LcTokens.spacingLg,
          LcTokens.spacingSm,
          LcTokens.spacingLg,
          LcTokens.spacingXxl,
        ),
        children: [
          Text(t.backupHelp, style: tt.bodyMedium),
          const SizedBox(height: LcTokens.spacingLg),
          FilledButton.icon(
            icon: const Icon(Icons.ios_share_rounded),
            label: Text(t.exportBackup),
            onPressed: _busy ? null : _export,
          ),
          const SizedBox(height: LcTokens.spacingMd),
          OutlinedButton.icon(
            icon: const Icon(Icons.restore_rounded),
            label: Text(t.importBackup),
            onPressed: _busy ? null : _import,
          ),
          SectionLabel(t.autoBackups),
          if (backups.isEmpty)
            Text(t.noBackups, style: tt.bodySmall)
          else
            LcCard(
              padding: const EdgeInsets.symmetric(vertical: LcTokens.spacingSm),
              child: Column(
                children: [
                  for (final b in backups)
                    ListTile(
                      title: Text(_fmt(b.createdUtc.toLocal())),
                      subtitle: Text(
                        '${_reason(t, b.reason)} · '
                        '${formatBytes(b.file.lengthSync())}',
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          if (await _confirm(
                            t.restoreConfirmTitle,
                            t.restoreConfirmBody,
                          )) {
                            _restore(b.file.path);
                          }
                        },
                        child: Text(t.restore),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _reason(AppLocalizations t, String r) => switch (r) {
    'before_update' => t.reasonBeforeUpdate,
    'before_content' => t.reasonBeforeContent,
    'before_migrate' => t.reasonBeforeMigrate,
    'before_restore' => t.reasonBeforeRestore,
    _ => t.reasonManual,
  };

  static String _fmt(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}
