import 'package:lincoin_core/lincoin_core.dart';

import 'study_repo.dart';
import 'user_db.dart';

/// A real-world reward the learner set for themselves.
class Reward {
  final String id;
  final String title;
  final String emoji;
  final int price;
  final bool repeatable;
  final int? cooldownDays;
  final bool active;
  final int sortOrder;

  const Reward({
    required this.id,
    required this.title,
    required this.emoji,
    required this.price,
    required this.repeatable,
    this.cooldownDays,
    this.active = true,
    this.sortOrder = 0,
  });
}

class Redemption {
  final String id;
  final String rewardId;
  final String title;
  final int price;
  final DateTime tsUtc;
  const Redemption(this.id, this.rewardId, this.title, this.price, this.tsUtc);
}

enum RedeemBlock { none, notEnough, cooldown, alreadyRedeemed }

class ShopRepo {
  final UserDb u;
  ShopRepo(this.u);

  List<Reward> rewards({bool includeInactive = false}) => [
    for (final r in u.db.select(
      'SELECT * FROM rewards ${includeInactive ? '' : 'WHERE active = 1'} '
      'ORDER BY sort_order, created_at',
    ))
      Reward(
        id: r['id'] as String,
        title: r['title'] as String,
        emoji: r['emoji'] as String,
        price: r['price'] as int,
        repeatable: (r['repeatable'] as int) == 1,
        cooldownDays: r['cooldown_days'] as int?,
        active: (r['active'] as int) == 1,
        sortOrder: r['sort_order'] as int,
      ),
  ];

  void save(Reward r, DateTime now) {
    final ms = now.millisecondsSinceEpoch;
    u.db.execute(
      'INSERT INTO rewards(id, title, emoji, price, repeatable, '
      'cooldown_days, active, sort_order, created_at, updated_at) '
      'VALUES (?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET '
      'title = excluded.title, emoji = excluded.emoji, '
      'price = excluded.price, repeatable = excluded.repeatable, '
      'cooldown_days = excluded.cooldown_days, active = excluded.active, '
      'sort_order = excluded.sort_order, updated_at = excluded.updated_at',
      [
        r.id,
        r.title,
        r.emoji,
        r.price,
        r.repeatable ? 1 : 0,
        r.cooldownDays,
        r.active ? 1 : 0,
        r.sortOrder,
        ms,
        ms,
      ],
    );
  }

  /// Rewards with redemptions are hidden, not deleted, to keep history.
  void remove(String id) {
    final used = u.db.select(
      'SELECT 1 FROM redemptions WHERE reward_id = ? LIMIT 1',
      [id],
    );
    if (used.isEmpty) {
      u.db.execute('DELETE FROM rewards WHERE id = ?', [id]);
    } else {
      u.db.execute('UPDATE rewards SET active = 0 WHERE id = ?', [id]);
    }
  }

  List<Redemption> redemptions({int limit = 50}) => [
    for (final r in u.db.select(
      'SELECT * FROM redemptions ORDER BY ts_utc DESC LIMIT ?',
      [limit],
    ))
      Redemption(
        r['id'] as String,
        r['reward_id'] as String,
        r['title'] as String,
        r['price'] as int,
        DateTime.fromMillisecondsSinceEpoch(r['ts_utc'] as int, isUtc: true),
      ),
  ];

  DateTime? lastRedeemed(String rewardId) {
    final r = u.db.select(
      'SELECT MAX(ts_utc) FROM redemptions WHERE reward_id = ?',
      [rewardId],
    );
    final ms = r.first.columnAt(0) as int?;
    return ms == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  /// When a cooldown blocks redeeming, the time it ends.
  DateTime? cooldownUntil(Reward r) {
    final last = lastRedeemed(r.id);
    if (last == null || r.cooldownDays == null || r.cooldownDays! <= 0) {
      return null;
    }
    return last.add(Duration(days: r.cooldownDays!));
  }

  RedeemBlock canRedeem(Reward r, DateTime now) {
    if (!r.repeatable && lastRedeemed(r.id) != null) {
      return RedeemBlock.alreadyRedeemed;
    }
    final until = cooldownUntil(r);
    if (until != null && now.isBefore(until)) return RedeemBlock.cooldown;
    if (LedgerRepo(u).balance() < r.price) return RedeemBlock.notEnough;
    return RedeemBlock.none;
  }

  /// Spends Lincoin on [r]. Throws if blocked.
  Redemption redeem(
    Reward r, {
    required DateTime nowUtc,
    required int studyDay,
    String? note,
  }) {
    final block = canRedeem(r, nowUtc);
    if (block != RedeemBlock.none) throw StateError(block.name);
    final id = UserDb.newId();
    final ledgerId = UserDb.newId();
    u.tx(() {
      LedgerRepo(u).insertAll([
        LedgerEntry(
          id: ledgerId,
          tsUtc: nowUtc,
          delta: -r.price,
          reason: LedgerReason.redeem,
          idempotencyKey: 'redeem:$id',
          refId: id,
          studyDay: studyDay,
          meta: {'rewardId': r.id, 'title': r.title},
        ),
      ]);
      u.db.execute(
        'INSERT INTO redemptions(id, reward_id, ledger_id, ts_utc, price, '
        'title, note) VALUES (?,?,?,?,?,?,?)',
        [
          id,
          r.id,
          ledgerId,
          nowUtc.millisecondsSinceEpoch,
          r.price,
          r.title,
          note,
        ],
      );
    });
    return Redemption(id, r.id, r.title, r.price, nowUtc);
  }
}
