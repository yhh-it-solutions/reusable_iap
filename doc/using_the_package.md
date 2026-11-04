# Using the package

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
