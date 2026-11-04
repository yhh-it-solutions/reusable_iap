import '../domain/entity/store_failure.dart';

abstract final class StoreStrings {
  static const title = 'Store';
  static const buy = 'Buy';
  static const restore = 'Restore Purchases';
  static const premium = 'Premium is on';
  static const notPremium = 'Premium is off';
  static const noStore = "Purchases aren't available on this device.";
  static const noProducts =
      'No products yet. Put your store IDs in store_catalog.dart.';

  static String coins(int coins) => 'Coins: $coins';

  static String failure(StoreFailure failure) => switch (failure) {
    StoreFailure.unavailable => noStore,
    StoreFailure.itemMissing => "This item isn't available right now.",
    StoreFailure.noConnection => "Couldn't load prices. Try again.",
    StoreFailure.purchaseFailed => "That didn't go through. Try again.",
    StoreFailure.notConfirmed =>
      "Couldn't confirm it. If you were charged, try Restore.",
    StoreFailure.stillFinishing => 'Reopen the app in a moment.',
    StoreFailure.restoreFailed => "Couldn't restore. Check your store account.",
  };
}
