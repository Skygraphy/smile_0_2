import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:smile_design_system/smile_design_system.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/plan_service.dart';
import '../services/play_billing.dart';
import 'redeem_voucher_screen.dart';

/// The Frame plan of a Space (2026-11-11): the sizes, which one the Space
/// has, buying / switching in Google Play (2026-11-17, via RevenueCat) and
/// redeeming a voucher. One person pays per Space; the others see who.
/// Pops with true when something changed.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, required this.spaceId, required this.spaceName, required this.plan});

  final String spaceId;
  final String spaceName;
  final SpacePlan? plan;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  static const _tiers = [
    (frames: 1, monthly: 4.99, yearly: 49.99, gb: 25, minutes: 5),
    (frames: 3, monthly: 8.99, yearly: 89.99, gb: 50, minutes: 10),
    (frames: 5, monthly: 12.99, yearly: 129.99, gb: 100, minutes: 10),
  ];

  SpacePlan? _plan;
  Map<String, StoreProduct> _products = const {};
  bool _loadingProducts = PlayBilling.available;
  bool _yearly = false;
  String? _busy;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
    _yearly = _plan?.playProduct?.endsWith(':yearly') ?? false;
    if (PlayBilling.available) _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await PlayBilling.loadProducts();
    if (!mounted) return;
    setState(() {
      _products = products;
      _loadingProducts = false;
    });
  }

  Future<void> _reload() async {
    try {
      final plan = await PlanService().load(widget.spaceId);
      if (mounted && plan != null) setState(() => _plan = plan);
    } catch (_) {
      // Keep what is shown; the Space page reloads anyway.
    }
  }

  Future<void> _buy(StoreProduct product) async {
    final t = SmileTexts.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = product.identifier);
    final result = await PlayBilling.buy(
      spaceId: widget.spaceId,
      product: product,
      currentProduct: _plan?.payerIsMe == true ? _plan?.playProduct : null,
    );
    if (!mounted) return;
    setState(() => _busy = null);
    final String? message = switch (result.outcome) {
      PlayBuyOutcome.bought => t.planThanks,
      PlayBuyOutcome.cancelled => null,
      PlayBuyOutcome.otherPayer => result.name == null ? t.planSomeonePays : t.planOtherPays(result.name!),
      PlayBuyOutcome.productInUse => t.planProductInUse(result.name ?? ''),
      PlayBuyOutcome.unavailable => t.planStoreUnavailable,
      PlayBuyOutcome.failed => t.planBuyFailed,
    };
    if (message != null) messenger.showSnackBar(SnackBar(content: Text(message)));
    if (result.outcome != PlayBuyOutcome.cancelled) {
      _changed = true;
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final money = NumberFormat.currency(locale: locale, symbol: '€', decimalDigits: 2);
    final date = DateFormat.yMMMMd(locale);
    final plan = _plan;
    final current = plan != null && plan.isActive ? plan.frames : null;
    final someoneElsePays = plan != null && plan.hasPayer && !plan.payerIsMe;
    final iPay = plan?.payerIsMe ?? false;
    final canBuy = PlayBilling.available && _products.isNotEmpty && !someoneElsePays;
    final period = _yearly ? 'yearly' : 'monthly';
    final muted = TextStyle(fontSize: 13, color: scheme.onSurfaceVariant);

    Widget note(String text, {Color? color}) => Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
          child: Text(text, style: TextStyle(fontSize: 13, color: color ?? scheme.onSurfaceVariant)),
        );

    Widget tier(({int frames, double monthly, double yearly, int gb, int minutes}) x) {
      final id = 'smile_frames_${x.frames}:$period';
      final product = _products[id];
      final price = product?.priceString ?? money.format(_yearly ? x.yearly : x.monthly);
      final mine = current == x.frames;
      final isMyProduct = iPay && plan?.playProduct == id;
      final busy = _busy == id;

      Widget? action;
      if (isMyProduct) {
        final ends = plan?.playEndsAt;
        action = Text(
          ends == null
              ? ''
              : plan?.playRenews == false
                  ? t.planYouPayEnds(date.format(ends))
                  : t.planYouPayNext(date.format(ends)),
          style: muted,
        );
      } else if (canBuy && product != null) {
        final child = busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(iPay ? t.planChange : t.planBuy);
        final onPressed = _busy == null ? () => _buy(product) : null;
        action = SizedBox(
          width: double.infinity,
          child: iPay
              ? OutlinedButton(onPressed: onPressed, child: child)
              : FilledButton(onPressed: onPressed, child: child),
        );
      }

      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: mine ? SmileTheme.primary.withValues(alpha: 0.12) : null,
          border: Border.all(color: mine ? SmileTheme.primary : scheme.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(child: Text(t.planFrames(x.frames), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5))),
                        if (mine) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: SmileTheme.primary.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(99)),
                            child: Text(
                              someoneElsePays ? t.planActive : t.planYours,
                              style: const TextStyle(color: SmileTheme.primary, fontSize: 11.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 2),
                      Text(t.planTierDetails(x.gb, x.minutes), style: muted),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(price, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                    Text(_yearly ? t.planPerYear : t.planPerMonth, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
            if (action != null) ...[const SizedBox(height: 10), action],
          ],
        ),
      );
    }

    final cover = plan?.coverEndsAt;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: SmileFitText(t.planSectionTitle)),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(t.planForSpace(widget.spaceName), style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: false, label: Text(t.planMonthly)),
                  ButtonSegment(value: true, label: Text('${t.planYearly} · ${t.planYearlyBonus}', overflow: TextOverflow.ellipsis)),
                ],
                selected: {_yearly},
                onSelectionChanged: (s) => setState(() => _yearly = s.first),
              ),
            ),
            for (final x in _tiers) tier(x),
            if (iPay && plan!.playBillingIssue) note(t.planBillingIssue, color: scheme.error),
            if (someoneElsePays) note(plan.payerName == null ? t.planSomeonePays : t.planOtherPays(plan.payerName!)),
            if (canBuy && !iPay && cover != null)
              note('${t.planCoverNote(date.format(cover))} ${t.planCancelAnytime}')
            else if (canBuy && !iPay)
              note(t.planCancelAnytime),
            if (PlayBilling.available && !_loadingProducts && _products.isEmpty) note(t.planStoreUnavailable),
            if (!PlayBilling.available)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                child: Text(t.planBuySoon, textAlign: TextAlign.center, style: muted),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              child: Text(t.planMoreFrames, textAlign: TextAlign.center, style: muted),
            ),
            if (iPay)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: OutlinedButton(
                  onPressed: () => launchUrl(PlayBilling.manageUri(plan!.playProduct), mode: LaunchMode.externalApplication),
                  child: Text(t.planManage),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: OutlinedButton.icon(
                icon: const Icon(SmileIcons.voucher),
                label: Text(t.redeemVoucher),
                onPressed: () async {
                  final done = await Navigator.of(context).push<bool>(MaterialPageRoute(
                    builder: (_) => RedeemVoucherScreen(spaceId: widget.spaceId, spaceName: widget.spaceName),
                  ));
                  if (done == true && context.mounted) Navigator.of(context).pop(true);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
