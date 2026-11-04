# reusable_iap

`reusable_iap` is a headless Flutter in-app purchase service built on top of [`in_app_purchase`](https://pub.dev/packages/in_app_purchase).

It wraps store availability checks, product loading, purchase updates, restore flows, entitlement mapping, verification, and purchase completion without forcing a paywall UI or a state-management package.

## Features

- Headless `IapServiceApi` for `initialize`, `loadProducts`, `buy`, `restore`, and entitlement checks
- Support for consumables, non-consumables, and subscriptions
- Normalized `IapProduct`, `IapPurchase`, `IapState`, and `IapError` models
- Centralized purchase lifecycle handling for pending, purchased, restored, canceled, and error states
- Internal transaction completion / acknowledgement handling
- App-defined entitlement mapping through `EntitlementResolver`
- App-defined verification through `PurchaseVerifier`
- Testable design through the `BillingGateway` abstraction

## What This Package Does Not Do

- Render a paywall
- Impose app branding or button styles
- Depend on Provider, Bloc, Riverpod, or any other state-management library
- Assume product IDs are the same thing as entitlements
- Force one backend verification strategy

## Installation

The package isn't on pub.dev, so depend on it from Git:

```yaml
dependencies:
  reusable_iap:
    git:
      url: https://github.com/yhh-it-solutions/reusable_iap.git
```

After adding the package, configure your products in App Store Connect / Google Play Console as usual.

## Quick Start

```dart
import 'package:reusable_iap/reusable_iap.dart';

final iap = IapService(
  config: IapConfig(
    products: {
      const IapProductDefinition.subscription('pro_monthly'),
      const IapProductDefinition.subscription('pro_yearly'),
      const IapProductDefinition.nonConsumable('lifetime_unlock'),
      const IapProductDefinition.consumable('coins_100'),
    },
  ),
  verifyPurchase: (purchase) async {
    // Call your backend when you need server-side validation.
    return true;
  },
  entitlementResolver: (purchase) {
    switch (purchase.productId) {
      case 'pro_monthly':
      case 'pro_yearly':
      case 'lifetime_unlock':
        return {'premium'};
      default:
        return const <String>{};
    }
  },
);

await iap.initialize();
final products = await iap.loadProducts();

final subscription = iap.state.listen((state) {
  if (state.error != null) {
    // Show a friendly error message.
  }

  if (iap.hasEntitlement('premium')) {
    // Unlock premium features.
  }
});

await iap.buy(products.first.id);
await iap.restore();

await subscription.cancel();
iap.dispose();
```

## Product IDs vs Entitlements

Product IDs are store-facing. Entitlements are app-facing.

That means products like `pro_monthly`, `pro_yearly`, and `lifetime_unlock` can all unlock the same entitlement such as `premium`.

## Public API

```dart
abstract interface class IapServiceApi {
  Stream<IapState> get state;
  IapState get currentState;
  Future<void> initialize();
  Future<List<IapProduct>> loadProducts();
  Future<void> buy(String productId);
  Future<void> restore();
  bool hasEntitlement(String entitlement);
  void dispose();
}
```

## Testing

The service depends on `BillingGateway`, not directly on `InAppPurchase.instance`, so you can unit test:

- store available / unavailable
- product catalog queries
- successful purchases
- canceled or failed purchases
- restore flows
- verification failures

## Example

A minimal example app is included in `example/lib/main.dart`. Replace the sample product IDs with your own and run it on a configured iOS or Android device.

## Good To Know

- **Restores arrive after `restore()` returns.** It resolves once the request is sent. Restored purchases come in on the state stream afterwards, so give them a moment before treating a user as not subscribed. If `error.code` is `restoreFailed`, the store couldn't answer, which doesn't mean the user isn't subscribed.
- **Entitlements only grow during a session.** A subscription that lapses while the app is open stays active until the next launch, when a fresh `restore()` finds only what's still active.
- **One plan per subscription product.** On Google Play the package uses the first base plan or offer the store returns for an ID, so price and purchase always match. To sell two plans, use two product IDs.
- **A failed verification leaves the purchase uncompleted.** The store sends it again, so a passing check can still deliver it, and Google Play refunds it if it's never acknowledged.
