import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../ui/input.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.g.dart';

/// Add or edit a song: title, artist and the pasted lyrics. Pops with the
/// song id when saved.
class SongEditScreen extends ConsumerStatefulWidget {
  final String? songId;
  const SongEditScreen({super.key, this.songId});

  @override
  ConsumerState<SongEditScreen> createState() => _SongEditScreenState();
}

class _SongEditScreenState extends ConsumerState<SongEditScreen> {
  final _title = TextEditingController();
  final _artist = TextEditingController();
  final _lyrics = TextEditingController();

  @override
  void initState() {
    super.initState();
    final id = widget.songId;
    if (id != null) {
      final s = ref.read(songRepoProvider).song(id);
      if (s != null) {
        _title.text = s.title;
        _artist.text = s.artist ?? '';
        _lyrics.text = s.lyrics;
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    _lyrics.dispose();
    super.dispose();
  }

  bool get _valid =>
      _title.text.trim().isNotEmpty && _lyrics.text.trim().isNotEmpty;

  void _save() {
    final id = ref
        .read(songRepoProvider)
        .save(
          id: widget.songId,
          title: _title.text.trim(),
          artist: _artist.text.trim().isEmpty ? null : _artist.text.trim(),
          lyrics: _lyrics.text,
          now: DateTime.now().toUtc(),
        );
    ref.read(dataVersionProvider.notifier).bump();
    Navigator.of(context).pop(id);
  }

  Future<void> _delete() async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.songDelete),
        content: Text(t.songDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          PressFilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.songDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    ref.read(songRepoProvider).delete(widget.songId!);
    ref.read(dataVersionProvider.notifier).bump();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.songId == null ? t.songAdd : t.songEdit),
        actions: [
          if (widget.songId != null)
            IconButton(
              tooltip: t.songDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(LcTokens.spacingLg),
          children: [
            TextField(
              controller: _title,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: t.songTitle),
            ),
            const SizedBox(height: LcTokens.spacingMd),
            TextField(
              controller: _artist,
              decoration: InputDecoration(labelText: t.songArtist),
            ),
            const SizedBox(height: LcTokens.spacingMd),
            TextField(
              controller: _lyrics,
              onChanged: (_) => setState(() {}),
              minLines: 10,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              style: jpStyle(18, 500, context.lc.ink),
              decoration: InputDecoration(
                labelText: t.songLyrics,
                hintText: t.songLyricsHint,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: LcTokens.spacingSm),
            Text(t.songPrivate, style: tt.bodySmall),
            const SizedBox(height: LcTokens.spacingLg),
            PressFilledButton(
              onPressed: _valid ? _save : null,
              child: Text(t.songSave),
            ),
          ],
        ),
      ),
    );
  }
}
