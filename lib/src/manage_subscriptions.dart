import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

/// Opens Apple's "manage subscriptions" sheet inside the app, listing only
/// this app's subscriptions. The player can cancel there.
///
/// Apps can't cancel a subscription themselves: only the store can. This
/// shows the store's own screen.
///
/// Returns `true` when the sheet was shown. Returns `false` when it can't be:
/// on Android and other platforms, on iOS 14 and older (StoreKit 2 only), or
/// when StoreKit fails. Open [manageSubscriptionsUri] instead in that case.
///
/// [platform] defaults to [defaultTargetPlatform]. [storeKit] replaces the
/// plugin in tests.
Future<bool> showManageSubscriptionsSheet({
  TargetPlatform? platform,
  @visibleForTesting InAppPurchaseStoreKitPlatformAddition? storeKit,
}) async {
  if (kIsWeb || (platform ?? defaultTargetPlatform) != TargetPlatform.iOS) {
    return false;
  }

  try {
    final addition = storeKit ??
        InAppPurchase.instance
            .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
    await addition.showManageSubscriptions();
    return true;
  } catch (_) {
    // iOS 14 and older, StoreKit 1, or no window to show the sheet in.
    return false;
  }
}

/// The store page where a player manages or cancels a subscription.
///
/// On Android, passing both [productId] and [packageName] opens that one
/// subscription in the Play Store. Without them it opens the list of all the
/// player's subscriptions.
///
/// On iOS and macOS it opens the list of every subscription on the Apple ID:
/// Apple has no link to a single app or subscription. Prefer
/// [showManageSubscriptionsSheet] on iOS, which lists only this app's
/// subscriptions, and use this as its fallback.
///
/// Open the result with `url_launcher`, in an external application.
/// [platform] defaults to [defaultTargetPlatform].
Uri manageSubscriptionsUri({
  String? productId,
  String? packageName,
  TargetPlatform? platform,
}) {
  switch (platform ?? defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return Uri.https('apps.apple.com', '/account/subscriptions');
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      final opensOne = productId != null && packageName != null;
      return Uri.https(
        'play.google.com',
        '/store/account/subscriptions',
        opensOne ? {'sku': productId, 'package': packageName} : null,
      );
  }
}
