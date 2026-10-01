import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../services/update_service.dart';
import '../../state/providers.dart';
import '../../state/update_controller.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.g.dart';
import '../../ui/widgets.dart';
import '../../ui/input.dart';

String formatBytes(int b) => b >= 1 << 20
    ? '${(b / (1 << 20)).toStringAsFixed(1)} MB'
    : '${(b / 1024).ceil()} KB';

class UpdatesScreen extends ConsumerWidget {
  const UpdatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final c = context.lc;
    final u = ref.watch(updateControllerProvider);
    final ctl = ref.read(updateControllerProvider.notifier);
    final app = ref.watch(appVersionProvider);
    final catalog = ref.watch(catalogProvider);
    final settings = ref.watch(settingsProvider);
    final prevContent = ref.watch(contentStoreProvider).previousVersion();
    final check = u.check;

    Future<void> show(UpdateOutcome o) async {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(o.messageTh)));
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.updates)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            LcTokens.spacingLg,
            LcTokens.spacingSm,
            LcTokens.spacingLg,
            LcTokens.spacingXxl,
          ),
          children: [
            LcCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv(context, t.appVersion, '${app.name} (${app.code})'),
                  _kv(
                    context,
                    t.contentVersion,
                    catalog?.info.version ?? t.none,
                  ),
                  _kv(
                    context,
                    t.lastChecked,
                    u.lastCheckedUtc == null
                        ? t.never
                        : _fmt(u.lastCheckedUtc!.toLocal()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: LcTokens.spacingLg),
            if (u.busy) ...[
              LcCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.busyLabel ?? '', style: tt.bodyLarge),
                    const SizedBox(height: LcTokens.spacingSm),
                    LinearProgressIndicator(value: u.progress),
                  ],
                ),
              ),
              const SizedBox(height: LcTokens.spacingLg),
            ],
            PressFilledButton.icon(
              icon: const Icon(Icons.cloud_download_outlined),
              label: Text(t.checkForUpdates),
              onPressed: u.busy || !settings.onlineUpdateCheck
                  ? null
                  : () async {
                      final err = await ctl.check();
                      if (err != null) await show(UpdateOutcome(false, err));
                    },
            ),
            const SizedBox(height: LcTokens.spacingMd),
            PressOutlinedButton.icon(
              icon: const Icon(Icons.folder_open_rounded),
              label: Text(t.updateFromFile),
              onPressed: u.busy ? null : () => _fromFile(context, ref),
            ),
            const SizedBox(height: LcTokens.spacingSm),
            Text(t.updateFromFileHelp, style: tt.bodySmall),
            if (u.error != null) ...[
              const SizedBox(height: LcTokens.spacingLg),
              LcPill(
                u.error!,
                bg: c.warnSoft,
                fg: c.warn,
                icon: Icons.wifi_off_rounded,
              ),
            ],
            if (check != null) ...[
              const SizedBox(height: LcTokens.spacingLg),
              if (!check.hasAny && !check.contentNeedsNewerApp)
                LcCard(
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: c.good),
                      const SizedBox(width: LcTokens.spacingMd),
                      Expanded(child: Text(t.upToDate, style: tt.bodyLarge)),
                    ],
                  ),
                ),
              if (check.appUpdate != null)
                _ReleaseCard(
                  title: t.newAppVersion(check.appUpdate!.versionName),
                  size: check.appUpdate!.sizeBytes,
                  changes: check.appUpdate!.changelogTh,
                  button: t.updateApp,
                  onPressed: u.busy
                      ? null
                      : () async =>
                            show(await ctl.installApp(check.appUpdate!)),
                ),
              if (check.contentUpdate != null)
                _ReleaseCard(
                  title: t.newContentVersion(check.contentUpdate!.version),
                  size: check.contentUpdate!.sizeBytes,
                  changes: check.contentUpdate!.changelogTh,
                  button: t.updateContent,
                  onPressed: u.busy
                      ? null
                      : () async => show(
                          await ctl.installContent(check.contentUpdate!),
                        ),
                ),
              if (check.contentNeedsNewerApp)
                Padding(
                  padding: const EdgeInsets.only(top: LcTokens.spacingMd),
                  child: Text(t.contentNeedsNewerApp, style: tt.bodySmall),
                ),
            ],
            SectionLabel(t.options),
            LcCard(
              padding: const EdgeInsets.symmetric(vertical: LcTokens.spacingSm),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(t.onlineCheck),
                    subtitle: Text(t.onlineCheckHelp),
                    value: settings.onlineUpdateCheck,
                    onChanged: (v) => ref
                        .read(settingsProvider.notifier)
                        .update((x) => x.copyWith(onlineUpdateCheck: v)),
                  ),
                  if (prevContent != null)
                    ListTile(
                      leading: const Icon(Icons.undo_rounded),
                      title: Text(t.rollbackContent(prevContent)),
                      onTap: u.busy
                          ? null
                          : () async {
                              final ok = await _confirm(
                                context,
                                t.rollbackContent(prevContent),
                                t.rollbackHelp,
                              );
                              if (ok) await show(ctl.rollbackContent());
                            },
                    ),
                ],
              ),
            ),
            const SizedBox(height: LcTokens.spacingMd),
            Text(t.updateSafety, style: tt.bodySmall),
          ],
        ),
      ),
    );
  }

  Future<void> _fromFile(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    final ctl = ref.read(updateControllerProvider.notifier);
    void snack(String m) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
      }
    }

    final FileUpdate? f;
    try {
      f = await ctl.pickFile();
    } on UpdateException catch (e) {
      snack(e.messageTh);
      return;
    }
    if (f == null || !context.mounted) return;
    final (title, body) = switch (f) {
      ApkFileUpdate(:final info) => (
        t.installAppFromFile(info.versionName),
        t.installAppFromFileHelp,
      ),
      ContentFileUpdate(:final pack, :final installedVersion) => (
        t.installContentFromFile(pack.manifest.version),
        [
          t.installedContent(installedVersion ?? t.none),
          ...pack.manifest.changelogTh.map((l) => '• $l'),
        ].join('\n'),
      ),
    };
    if (!await _confirm(context, title, body)) return;
    snack((await ctl.applyFile(f)).messageTh);
  }

  static Future<bool> _confirm(
    BuildContext context,
    String title,
    String body,
  ) async {
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
              PressFilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(t.confirm),
              ),
            ],
          ),
        ) ??
        false;
  }

  static Widget _kv(BuildContext context, String k, String v) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: tt.bodyMedium?.copyWith(color: context.lc.muted),
            ),
          ),
          Text(v, style: tt.bodyLarge),
        ],
      ),
    );
  }

  static String _fmt(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _ReleaseCard extends StatelessWidget {
  final String title;
  final int size;
  final List<String> changes;
  final String button;
  final VoidCallback? onPressed;
  const _ReleaseCard({
    required this.title,
    required this.size,
    required this.changes,
    required this.button,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: LcTokens.spacingMd),
      child: LcCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: tt.titleMedium)),
                Text(formatBytes(size), style: tt.bodySmall),
              ],
            ),
            const SizedBox(height: LcTokens.spacingSm),
            for (final c in changes) Text('• $c', style: tt.bodyMedium),
            const SizedBox(height: LcTokens.spacingMd),
            SizedBox(
              width: double.infinity,
              child: PressFilledButton(
                onPressed: onPressed,
                child: Text(button),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
