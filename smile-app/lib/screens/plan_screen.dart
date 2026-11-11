import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/plan_service.dart';
import 'redeem_voucher_screen.dart';

/// The Frame plan of a Space (2026-11-11): the four sizes, which one the
/// Space has, and redeeming a voucher. Buying via Google Play comes later
/// (RevenueCat) -- until then the sizes are shown, vouchers already work.
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key, required this.spaceId, required this.spaceName, required this.plan});

  final String spaceId;
  final String spaceName;
  final SpacePlan? plan;

  static const _tiers = [
    (frames: 1, price: 4.99, gb: 25, minutes: 5),
    (frames: 3, price: 8.99, gb: 50, minutes: 10),
    (frames: 5, price: 12.99, gb: 100, minutes: 10),
  ];

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final scheme = Theme.of(context).colorScheme;
    final money = NumberFormat.currency(locale: Localizations.localeOf(context).toLanguageTag(), symbol: '€', decimalDigits: 2);
    final current = plan != null && plan!.isActive ? plan!.frames : null;

    Widget tier({required String title, required String details, required String price, required String per, required bool mine}) =>
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: mine ? SmileTheme.primary.withValues(alpha: 0.12) : null,
            border: Border.all(color: mine ? SmileTheme.primary : scheme.outlineVariant),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5))),
                      if (mine) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: SmileTheme.primary.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(99)),
                          child: Text(t.planYours, style: const TextStyle(color: SmileTheme.primary, fontSize: 11.5, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(details, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(price, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                  Text(per, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: SmileFitText(t.planSectionTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Text(t.planForSpace(spaceName), style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          for (final x in _tiers)
            tier(
              title: t.planFrames(x.frames),
              details: t.planTierDetails(x.gb, x.minutes),
              price: money.format(x.price),
              per: t.planPerMonth,
              mine: current == x.frames,
            ),
          tier(
            title: t.planTierMore,
            details: t.planTierMoreDetails,
            price: '+${money.format(1.99)}',
            per: t.planPerExtraFrame,
            mine: current != null && current > 5,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 18),
            child: Text(t.planYearlyHint, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(t.planBuySoon, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: FilledButton.icon(
              icon: const Icon(SmileIcons.voucher),
              label: Text(t.redeemVoucher),
              onPressed: () async {
                final done = await Navigator.of(context).push<bool>(MaterialPageRoute(
                  builder: (_) => RedeemVoucherScreen(spaceId: spaceId, spaceName: spaceName),
                ));
                if (done == true && context.mounted) Navigator.of(context).pop(true);
              },
            ),
          ),
        ],
      ),
    );
  }
}
