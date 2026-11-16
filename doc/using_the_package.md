# Using the package

The API, step by step. To see how it all fits in a real app with layers, read [clean architecture](clean_architecture.md) next.

## Install

From your app's folder:

```bash
flutter pub add reusable_iap --git-url=https://github.com/yhh-it-solutions/reusable_iap.git
```

The package lives on GitHub, not pub.dev, which is why it needs the URL. The command adds this to `pubspec.yaml`. You can also write it by hand and run `flutter pub get`:

```yaml
dependencies:
  reusable_iap:
    git: https://github.com/yhh-it-solutions/reusable_iap.git
```

Then import it wherever you use it:

```dart
import 'package:reusable_iap/reusable_iap.dart';
```

Don't add `in_app_purchase` yourself, because it comes with this package.

| Needs | Minimum |
|---|---|
| Dart | 3.11.1 |
| Android | API 23 |
| iOS | 15, because the plugin uses StoreKit 2 |

**Staying on a version.** `pubspec.lock` records the exact commit, so commit that file and your whole team builds the same code. To move to the newest commit:

```bash
flutter pub upgrade reusable_iap
```

To hold one version even through upgrades, add a `ref`, which can be a commit, branch or tag:

```yaml
dependencies:
  reusable_iap:
    git:
      url: https://github.com/yhh-it-solutions/reusable_iap.git
      ref: 52f929d
```

**The stores come next.** The package compiles without them, but nothing can be bought until your products exist and iOS has the In-App Purchase capability. See [store setup](store_setup.md).

## 1. List your products

```dart
final iap = IapService(
  config: IapConfig(
    products: {
      const IapProductDefinition.subscription('pro_monthly'),
      const IapProductDefinition.nonConsumable('lifetime'),
      const IapProductDefinition.consumable('coins_100'),
    },
  ),
  entitlementResolver: (purchase) => switch (purchase.productId) {
    'pro_monthly' || 'lifetime' => {'premium'},
    _ => const <String>{},
  },
);
```

Keep product IDs in the store's terms and entitlements in your app's. Adding a yearly plan later then changes one line, not every screen.

## 2. Start early

```dart
await iap.initialize();
await iap.loadProducts();
```

Call these at app start, not when the paywall opens. A purchase that finished while the app was closed arrives as soon as you listen, and it can arrive at any time.

## 3. Draw from state

Everything you need is on `iap.state`, a stream of `IapState`:

| Field | Use it for |
|---|---|
| `products` | Names and localized prices. Always show `product.price`, never a hard-coded one |
| `loading` | Disabling buttons while a store call runs |
| `restoring` | The restore button's own spinner |
| `available` | Hiding the paywall where the store can't be used |
| `activeEntitlements` | What the user can access |
| `error` | Telling the user what went wrong |
| `lastPurchase` | What just happened, and its status |

`iap.currentState` gives the latest one without listening, and `iap.hasEntitlement('premium')` is a shortcut.

## 4. Buy and restore

```dart
await iap.buy('pro_monthly');
await iap.restore();
```

Neither returns the result. It arrives on `state`, because the store can take minutes and the app may restart in between.

## 5. Check access on launch

Entitlements live in memory, so ask the store again each launch and save the answer:

```dart
await iap.initialize();
if (!iap.currentState.available) return; // Says nothing about the user: keep the saved value.

await iap.restore();

// restore() returns once the request is sent. Purchases arrive just after.
await Future<void>.delayed(const Duration(seconds: 2));

if (iap.currentState.error?.code == IapErrorCode.restoreFailed) return; // Same again.
await saveIsPremium(iap.hasEntitlement('premium'));
```

Save the result so a subscriber sees no ads while offline. Only change it when the store really answered. A subscription that lapses mid-session stays active until the next launch.

Also listen for `activeEntitlements` changes, so access turns on the moment someone buys.

## 6. Handle errors

Show your own wording, based on `error.code`:

| Code | What it means | Tell the user |
|---|---|---|
| `storeUnavailable` | Purchases are off on this device | Purchases aren't available here |
| `emptyCatalog`, `productsNotFound`, `unknownProduct` | Your setup: see [troubleshooting](troubleshooting.md) | This item isn't available right now |
| `productQueryFailed` | The store couldn't be reached | Couldn't load prices. Try again |
| `purchaseCancelled` | The user closed the sheet | Usually nothing |
| `purchaseFailed` | The payment failed or never started | That didn't go through. Try again |
| `verificationFailed` | Your check said no, or threw | Couldn't confirm it. If you were charged, try Restore |
| `purchaseStreamFailed` | The purchase stream broke | Something went wrong. Try again |
| `purchaseCompletionFailed` | Paid, but couldn't complete it. It retries next launch | Reopen the app in a moment |
| `restoreFailed` | The store couldn't answer | Couldn't restore. Check your store account |

## 7. Clean up

```dart
iap.dispose();
```

## 8. Let players manage or cancel

No app can cancel a subscription; only the store can. Open the store's own screen and let the player cancel there:

```dart
Future<void> manageSubscription() async {
  if (await showManageSubscriptionsSheet()) return; // iOS 15+: in-app sheet, this app only

  await launchUrl(
    manageSubscriptionsUri(
      productId: 'pro_monthly',          // Android: opens this subscription
      packageName: 'com.example.app',    // Android: needed together with productId
    ),
    mode: LaunchMode.externalApplication,
  );
}
```

| Platform | What the player sees |
|---|---|
| iOS 15+ | A sheet inside your app with only your app's subscriptions |
| Older iOS, or if the sheet fails | The App Store's list of every subscription on the Apple ID. Apple has no link to one app's subscriptions |
| Android, with `productId` and `packageName` | Your subscription in the Play Store app |
| Android, without them | The Play Store's list of every subscription on the Google account |

`url_launcher` is your app's dependency, not the package's.

A cancelled subscription keeps working until the period it was paid for ends. After that the store stops returning it, and your launch check from step 5 removes access. There is nothing to listen for.

## Testing

The service talks to the store through `BillingGateway`, so tests never touch a real store:

```dart
class FakeGateway implements BillingGateway {
  final purchases = StreamController<List<BillingPurchase>>.broadcast();

  @override
  Stream<List<BillingPurchase>> get purchaseStream => purchases.stream;

  @override
  Future<bool> isAvailable() async => true;

  // queryProducts, buyConsumable, buyNonConsumable, restorePurchases and
  // completePurchase work the same way.
}

final iap = IapService(config: config, gateway: FakeGateway());
```

Push a `BillingPurchase` onto the stream and assert on `iap.currentState`. See [`test/reusable_iap_test.dart`](../test/reusable_iap_test.dart). Real purchases still need a real device and test accounts.

## Read more

- [Clean architecture](clean_architecture.md): where each of these pieces goes in a real app.
- [Flutter In-App Purchases: The Complete 2026 Guide](https://bimalkhatri.com.np/blogs/flutter-in-app-purchases-guide): the whole journey, from store setup to fees.
- [Flutter in_app_purchase Tutorial: Coins and Subscriptions](https://bimalkhatri.com.np/blogs/flutter-in-app-purchase-tutorial): the same flow built directly on the plugin, so you can see what this package takes care of.
