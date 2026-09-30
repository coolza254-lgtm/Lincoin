import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/shop_repo.dart';
import '../../data/study_repo.dart';
import '../../data/user_db.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.g.dart';
import '../../ui/widgets.dart';

class ShopData {
  final List<Reward> rewards;
  final List<Redemption> history;
  final double avgIncome7;
  const ShopData(this.rewards, this.history, this.avgIncome7);
}

final shopDataProvider = Provider<ShopData>((ref) {
  ref.watch(dataVersionProvider);
  final shop = ref.watch(shopRepoProvider);
  final svc = ref.watch(studyServiceProvider);
  final day = svc?.studyDay() ?? 0;
  final earned = LedgerRepo(ref.watch(userDbProvider))
      .entries(fromDay: day - 6)
      .where((e) => e.delta > 0)
      .fold(0, (a, e) => a + e.delta);
  return ShopData(shop.rewards(), shop.redemptions(limit: 20), earned / 7);
});

/// Real-world rewards the learner sets and buys with Lincoin.
class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final balance = ref.watch(balanceProvider);
    final data = ref.watch(shopDataProvider);
    return SafeArea(
      child: ListView(
        key: const PageStorageKey('shop'),
        padding: const EdgeInsets.fromLTRB(
          LcTokens.spacingXl,
          LcTokens.spacingMd,
          LcTokens.spacingXl,
          LcTokens.spacingXxl,
        ),
        children: [
          Text(t.tabShop, style: tt.headlineMedium),
          const SizedBox(height: LcTokens.spacingLg),
          LcCard(
            large: true,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.balance, style: tt.bodySmall),
                      const SizedBox(height: 4),
                      CoinChip(balance, large: true),
                    ],
                  ),
                ),
                StatTile(data.avgIncome7.toStringAsFixed(0), t.avgPerDay),
              ],
            ),
          ),
          const SizedBox(height: LcTokens.spacingLg),
          if (data.rewards.isEmpty)
            LcCard(
              child: EmptyState(
                icon: Icons.card_giftcard_rounded,
                title: t.noRewardsTitle,
                body: t.noRewardsBody,
              ),
            ),
          for (final r in data.rewards)
            Padding(
              padding: const EdgeInsets.only(bottom: LcTokens.spacingMd),
              child: _RewardCard(reward: r, balance: balance),
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: Text(t.addReward),
            onPressed: () => editReward(context, ref, null),
          ),
          if (data.history.isNotEmpty) ...[
            SectionLabel(t.redeemHistory),
            LcCard(
              padding: const EdgeInsets.symmetric(vertical: LcTokens.spacingSm),
              child: Column(
                children: [
                  for (final h in data.history)
                    ListTile(
                      title: Text(h.title),
                      subtitle: Text(_date(h.tsUtc.toLocal())),
                      trailing: CoinChip(-h.price, signed: true),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

class _RewardCard extends ConsumerWidget {
  final Reward reward;
  final int balance;
  const _RewardCard({required this.reward, required this.balance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final shop = ref.read(shopRepoProvider);
    final now = DateTime.now().toUtc();
    final block = shop.canRedeem(reward, now);
    final status = switch (block) {
      RedeemBlock.none => t.readyToRedeem,
      RedeemBlock.notEnough => t.needMore(reward.price - balance),
      RedeemBlock.cooldown => t.cooldownUntil(
        _date(shop.cooldownUntil(reward)!.toLocal()),
      ),
      RedeemBlock.alreadyRedeemed => t.alreadyRedeemed,
    };
    return LcCard(
      onTap: () => editReward(context, ref, reward),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(reward.emoji, style: const TextStyle(fontSize: 36)),
              const SizedBox(width: LcTokens.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reward.title, style: tt.titleMedium),
                    Text(
                      [
                        if (!reward.repeatable) t.oneTime,
                        if (reward.cooldownDays != null &&
                            reward.cooldownDays! > 0)
                          t.everyNDays(reward.cooldownDays!),
                      ].join(' · '),
                      style: tt.bodySmall,
                    ),
                  ],
                ),
              ),
              CoinChip(reward.price),
            ],
          ),
          const SizedBox(height: LcTokens.spacingMd),
          LcProgressBar(balance / reward.price, color: context.lc.coin),
          const SizedBox(height: LcTokens.spacingSm),
          Row(
            children: [
              Expanded(child: Text(status, style: tt.bodySmall)),
              FilledButton(
                onPressed: block == RedeemBlock.none
                    ? () => _redeem(context, ref)
                    : null,
                child: Text(t.redeem),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _redeem(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${reward.emoji} ${reward.title}'),
        content: Text(t.redeemConfirm(reward.price)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.redeem),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final svc = ref.read(studyServiceProvider);
    final now = DateTime.now().toUtc();
    ref
        .read(shopRepoProvider)
        .redeem(reward, nowUtc: now, studyDay: svc?.studyDay(now) ?? 0);
    ref.read(dataVersionProvider.notifier).bump();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.redeemed(reward.title))));
    }
  }

  static String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

/// Add ([r] == null) or edit a reward.
Future<void> editReward(BuildContext context, WidgetRef ref, Reward? r) async {
  final t = AppLocalizations.of(context);
  final title = TextEditingController(text: r?.title);
  final emoji = TextEditingController(text: r?.emoji ?? '🎁');
  final price = TextEditingController(text: r == null ? '' : '${r.price}');
  final cooldown = TextEditingController(
    text: r?.cooldownDays == null ? '' : '${r!.cooldownDays}',
  );
  var repeatable = r?.repeatable ?? true;
  final formKey = GlobalKey<FormState>();

  final action = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
        LcTokens.spacingXl,
        0,
        LcTokens.spacingXl,
        MediaQuery.of(ctx).viewInsets.bottom + LcTokens.spacingXl,
      ),
      child: StatefulBuilder(
        builder: (ctx, setState) => Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                r == null ? t.addReward : t.editReward,
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: LcTokens.spacingLg),
              Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: TextFormField(
                      controller: emoji,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24),
                      decoration: InputDecoration(labelText: t.emoji),
                    ),
                  ),
                  const SizedBox(width: LcTokens.spacingMd),
                  Expanded(
                    child: TextFormField(
                      controller: title,
                      decoration: InputDecoration(labelText: t.rewardTitle),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? t.required : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: LcTokens.spacingMd),
              TextFormField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: t.price,
                  helperText: t.priceHelp,
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n <= 0 || n > 1000000
                      ? t.invalidNumber
                      : null;
                },
              ),
              const SizedBox(height: LcTokens.spacingMd),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.repeatable),
                value: repeatable,
                onChanged: (v) => setState(() => repeatable = v),
              ),
              if (repeatable)
                TextFormField(
                  controller: cooldown,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: t.cooldownDays),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    final n = int.tryParse(v);
                    return n == null || n < 0 || n > 365
                        ? t.invalidNumber
                        : null;
                  },
                ),
              const SizedBox(height: LcTokens.spacingLg),
              Row(
                children: [
                  if (r != null)
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, 'delete'),
                      child: Text(t.delete),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(t.cancel),
                  ),
                  const SizedBox(width: LcTokens.spacingSm),
                  FilledButton(
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        Navigator.pop(ctx, 'save');
                      }
                    },
                    child: Text(t.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  final shop = ref.read(shopRepoProvider);
  if (action == 'delete' && r != null) {
    shop.remove(r.id);
    if (context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(t.rewardDeleted(r.title)),
          action: SnackBarAction(
            label: t.undo,
            onPressed: () {
              shop.save(r, DateTime.now().toUtc());
              ref.read(dataVersionProvider.notifier).bump();
            },
          ),
        ),
      );
    }
  } else if (action == 'save') {
    final cd = int.tryParse(cooldown.text);
    shop.save(
      Reward(
        id: r?.id ?? UserDb.newId(),
        title: title.text.trim(),
        emoji: emoji.text.trim().isEmpty ? '🎁' : emoji.text.trim(),
        price: int.parse(price.text),
        repeatable: repeatable,
        cooldownDays: repeatable && cd != null && cd > 0 ? cd : null,
        sortOrder: r?.sortOrder ?? 0,
      ),
      DateTime.now().toUtc(),
    );
  } else {
    return;
  }
  ref.read(dataVersionProvider.notifier).bump();
}
