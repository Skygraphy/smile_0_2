import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../main.dart';
import 'edge_functions.dart';
import 'test_media.dart' show smileTestMode;

/// What came of trying to buy or switch.
enum PlayBuyOutcome { bought, cancelled, otherPayer, productInUse, unavailable, failed }

class PlayBuyResult {
  const PlayBuyResult(this.outcome, {this.name});

  final PlayBuyOutcome outcome;

  /// The payer's name (otherPayer) or the other Space's name (productInUse).
  final String? name;
}

/// Frame plans bought in Google Play through RevenueCat (2026-11-17,
/// migrations/0105). RevenueCat knows the buyer by their Smile user id;
/// which Space a purchase is for the server learns right before buying
/// (play-subscription, prepare). The Space's plan itself always comes from
/// the server (space_plan), never from the store directly.
class PlayBilling {
  PlayBilling._();

  static const _apiKey = 'goog_KEOjYWpKnGViRfAAkjurZcpnKtw';

  /// Google subscription ids; each has the base plans 'monthly' and 'yearly'.
  static const products = ['smile_frames_1', 'smile_frames_3', 'smile_frames_5'];

  /// Only the real Android app; the test app talks to the testsuite project.
  static bool get available => !kIsWeb && Platform.isAndroid && !smileTestMode;

  static String? _configuredFor;

  static Future<void> _ensure() async {
    final me = supabase.auth.currentUser?.id;
    if (me == null) throw StateError('signed out');
    if (_configuredFor == me) return;
    if (_configuredFor == null && !await Purchases.isConfigured) {
      await Purchases.configure(PurchasesConfiguration(_apiKey)..appUserID = me);
    } else {
      await Purchases.logIn(me);
    }
    _configuredFor = me;
  }

  /// 'smile_frames_3:monthly' -> product, with Google's price in the
  /// buyer's currency. Empty when the store cannot be reached.
  static Future<Map<String, StoreProduct>> loadProducts() async {
    if (!available) return const {};
    try {
      await _ensure();
      final list = await Purchases.getProducts(products);
      return {for (final p in list) p.identifier: p};
    } catch (e) {
      debugPrint('PlayBilling.loadProducts: $e');
      return const {};
    }
  }

  /// Buys [product] for [spaceId]. With [currentProduct] ('smile_frames_1:monthly')
  /// it is a switch: the new tier applies at once, the billing day stays and
  /// the new price starts there (no proration; Google cannot prorate a
  /// subscription whose renewal was deferred for voucher or trial time).
  static Future<PlayBuyResult> buy({required String spaceId, required StoreProduct product, String? currentProduct}) async {
    final base = product.identifier.split(':').first;
    try {
      await _ensure();
      final prep = await invokeEdge('play-subscription', body: {'action': 'prepare', 'space_id': spaceId, 'product': base});
      final data = prep.data as Map<String, dynamic>?;
      switch (data?['error']) {
        case null:
          break;
        case 'other_payer':
          return PlayBuyResult(PlayBuyOutcome.otherPayer, name: data?['payer_name'] as String?);
        case 'product_in_use':
          return PlayBuyResult(PlayBuyOutcome.productInUse, name: data?['space_name'] as String?);
        default:
          return const PlayBuyResult(PlayBuyOutcome.failed);
      }

      final old = currentProduct?.split(':').first;
      await Purchases.purchase(PurchaseParams.storeProduct(
        product,
        productChangeInfo: old == null
            ? null
            : StoreProductChangeInfo(old, replacementMode: StoreReplacementMode.withoutProration),
      ));
      await sync();
      return const PlayBuyResult(PlayBuyOutcome.bought);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      debugPrint('PlayBilling.buy: $code ${e.message}');
      if (code == PurchasesErrorCode.purchaseCancelledError) return const PlayBuyResult(PlayBuyOutcome.cancelled);
      if (code == PurchasesErrorCode.storeProblemError ||
          code == PurchasesErrorCode.networkError ||
          code == PurchasesErrorCode.purchaseNotAllowedError) {
        return const PlayBuyResult(PlayBuyOutcome.unavailable);
      }
      return const PlayBuyResult(PlayBuyOutcome.failed);
    } catch (e) {
      debugPrint('PlayBilling.buy: $e');
      return const PlayBuyResult(PlayBuyOutcome.failed);
    }
  }

  /// Asks the server to read RevenueCat now (the webhook also does it).
  static Future<void> sync() async {
    try {
      await invokeEdge('play-subscription', body: {'action': 'sync'});
    } catch (e) {
      debugPrint('PlayBilling.sync: $e');
    }
  }

  /// Google Play's own subscription page for Smile (cancel, payment method).
  static Uri manageUri(String? product) => Uri.parse(
        'https://play.google.com/store/account/subscriptions?package=com.smile.smile_app'
        '${product == null ? '' : '&sku=${product.split(':').first}'}',
      );

  /// The Spaces this person pays for in Google Play and that will renew.
  static Future<List<String>> myPaidSpaceNames({String? onlySpace}) async {
    try {
      final rows = await supabase.rpc('my_play_payments') as List;
      return [
        for (final r in rows)
          if (onlySpace == null || r['space_id'] == onlySpace) r['space_name'] as String,
      ];
    } catch (_) {
      return const [];
    }
  }
}
