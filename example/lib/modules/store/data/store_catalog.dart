import 'package:reusable_iap/reusable_iap.dart';

/// Store product IDs live here and nowhere else.
abstract final class StoreCatalog {
  static const proMonthly = 'pro_monthly';
  static const proYearly = 'pro_yearly';
  static const lifetimeUnlock = 'lifetime_unlock';
  static const coins100 = 'coins_100';

  static const premium = 'premium';
  static const coinsPerPack = 100;

  static IapConfig get config => IapConfig(
    products: {
      const IapProductDefinition.subscription(proMonthly),
      const IapProductDefinition.subscription(proYearly),
      const IapProductDefinition.nonConsumable(lifetimeUnlock),
      const IapProductDefinition.consumable(coins100),
    },
  );

  /// Screens ask about `premium`, so a new plan changes this one line.
  static Set<String> entitlementsFor(IapPurchase purchase) =>
      switch (purchase.productId) {
        proMonthly || proYearly || lifetimeUnlock => const {premium},
        _ => const <String>{},
      };
}
