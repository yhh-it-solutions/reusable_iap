# reusable_iap

**In-app purchases for Flutter, without the plumbing.** Sell subscriptions, consumables and non-consumables on the App Store and Google Play through one small API. You keep your own paywall, your own state management and, if you have one, your own backend.

Built on Flutter's official [`in_app_purchase`](https://pub.dev/packages/in_app_purchase) plugin, so it runs on StoreKit 2 and Google Play Billing with no third party in between.

## What it is, and what it isn't

| It is | It isn't |
|---|---|
| A headless layer over the official plugin | A paywall, or any UI at all |
| One stream of state: products, loading, errors, what the user owns | A hosted service like RevenueCat: no dashboard, no charts, no sign-up, no fee |
| The purchase lifecycle done for you: pending, restore, completing | A server. It can call yours, but it doesn't come with one |
| Products mapped to access, so `pro_monthly` and `lifetime` can both mean `premium` | A way to take card payments or sell physical goods |

New to this? [What in-app purchases are](doc/in_app_purchases_explained.md), including subscriptions, consumables and non-consumables.

## Should you use it?

**Use it if** you sell from a Flutter app on the App Store and Google Play, want no one between you and the stores, and either have your own backend or are selling something low-stakes like removing ads.

**Skip it if** you:

- want renewal tracking across devices, charts and hosted paywalls without running a server. Use [RevenueCat](https://www.revenuecat.com/).
- need several plans under one product, promotional offers or upgrade paths. Use `in_app_purchase` directly.
- sell physical goods or anything used outside the app. Stores don't allow in-app purchases for those. Use a payment provider like Stripe.

## Quick start

```yaml
dependencies:
  reusable_iap:
    git:
      url: https://github.com/yhh-it-solutions/reusable_iap.git
```

```dart
final iap = IapService(
  config: IapConfig(
    products: {
      const IapProductDefinition.subscription('pro_monthly'),
      const IapProductDefinition.nonConsumable('lifetime'),
      const IapProductDefinition.consumable('coins_100'),
    },
  ),
  // Which access each purchase gives.
  entitlementResolver: (purchase) => switch (purchase.productId) {
    'pro_monthly' || 'lifetime' => {'premium'},
    _ => const <String>{},
  },
);

iap.state.listen((state) {
  // Draw your paywall from state.products, state.loading and state.error.
  final isPremium = state.activeEntitlements.contains('premium');
});

await iap.initialize();      // As early as you can, at app start.
await iap.loadProducts();
await iap.buy('pro_monthly');
await iap.restore();         // Behind a "Restore Purchases" button.
```

The code is the small part. Products must exist in both stores first:

| Step | Where | What |
|---|---|---|
| 1. Paperwork | App Store Connect, Play Console | Paid Apps Agreement, tax and bank; payments profile |
| 2. A build | Xcode, Play Console | In-App Purchase capability; a build on a testing track |
| 3. Products | App Store Connect, Play Console | Create them with the same IDs as your code, and activate them |
| 4. Testers | App Store Connect, Play Console | Sandbox accounts; license testers |

The [store setup guide](doc/store_setup.md) walks through each one.

## Can it work with my own backend?

Yes. Pass `verifyPurchase` and nothing is granted until your server says the purchase is real:

```dart
IapService(
  config: config,
  verifyPurchase: (purchase) => myApi.verify(
    store: purchase.verificationData!.source,
    proof: purchase.verificationData!.serverVerificationData,
    productId: purchase.productId,
  ),
);
```

Without it, the app trusts the store's answer on the device. That's fine for removing ads, but not for coins or paid content. See [using your own backend](doc/your_own_backend.md).

## Docs

- [In-app purchases explained](doc/in_app_purchases_explained.md): the concepts and the three product types
- [Store setup](doc/store_setup.md): what you need, what to create, and where
- [Using the package](doc/using_the_package.md): from catalog to paywall, errors and testing
- [Your own backend](doc/your_own_backend.md): verifying purchases on your server
- [Troubleshooting](doc/troubleshooting.md): products not found, refunds, stuck purchases

A runnable example is in [`example/`](example/lib/main.dart).

<!--
Blog links to add here when the in-app purchases series is published on
bimalkhatri.com.np/blogs (all 404 on 2026-11-04, so not linked yet):
flutter-in-app-purchases-guide, in-app-purchase-vs-revenuecat,
in-app-purchase-terms-explained, app-store-connect-in-app-purchases,
google-play-one-time-products-subscriptions, verify-in-app-purchases-server,
flutter-in-app-purchase-not-working.
-->
