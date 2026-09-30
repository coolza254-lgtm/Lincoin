import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.g.dart';
import '../../ui/widgets.dart';

/// Credits for every content source (read from content.db, so they always
/// match the installed content), fonts and software licences.
class CreditsScreen extends ConsumerWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final catalog = ref.watch(catalogProvider);
    final app = ref.watch(appVersionProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.credits)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            LcTokens.spacingLg,
            0,
            LcTokens.spacingLg,
            LcTokens.spacingXxl,
          ),
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(LcTokens.radiusCardLarge),
                child: Image.asset(
                  'assets/brand/logo.png',
                  width: 160,
                  semanticLabel: 'Lincoin',
                ),
              ),
            ),
            const SizedBox(height: LcTokens.spacingSm),
            Center(
              child: Text(
                t.versionLine(app.name, catalog?.info.version ?? '-'),
                style: tt.bodySmall,
              ),
            ),
            SectionLabel(t.contentSources),
            if (catalog == null)
              Text(t.none, style: tt.bodySmall)
            else
              for (final s in catalog.sources)
                Padding(
                  padding: const EdgeInsets.only(bottom: LcTokens.spacingMd),
                  child: LcCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name, style: tt.titleMedium),
                        const SizedBox(height: 4),
                        LcPill(s.license),
                        const SizedBox(height: LcTokens.spacingSm),
                        Text(s.attribution, style: tt.bodyMedium),
                        const SizedBox(height: LcTokens.spacingSm),
                        SelectableText(
                          s.homepage,
                          style: tt.bodySmall?.copyWith(
                            color: context.lc.accent,
                          ),
                        ),
                        SelectableText(s.licenseUrl, style: tt.bodySmall),
                      ],
                    ),
                  ),
                ),
            Text(t.contentLicenseNote, style: tt.bodySmall),
            SectionLabel(t.fonts),
            LcCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IBM Plex Sans Thai — © IBM Corp.',
                    style: tt.bodyMedium,
                  ),
                  Text(
                    'Zen Maru Gothic — © The Zen Maru Gothic Project Authors',
                    style: tt.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text('SIL Open Font License 1.1', style: tt.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: LcTokens.spacingLg),
            OutlinedButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'Lincoin',
                applicationVersion: app.name,
              ),
              child: Text(t.softwareLicenses),
            ),
          ],
        ),
      ),
    );
  }
}
