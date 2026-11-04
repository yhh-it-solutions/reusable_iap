# Reusable IAP Example

A small store in clean architecture: two subscriptions, a lifetime unlock and a coin pack. Only `data/` knows `reusable_iap` exists. The [clean architecture guide](../doc/clean_architecture.md) explains every layer.

## Run the tests

This folder holds only Dart code, because the bundle ID has to be yours. The tests need no store and no device:

```bash
cd example
flutter pub get
flutter test
```

## Run it on a device

Generate the platform folders. They're ignored by Git:

```bash
flutter create --platforms=android,ios --org com.yourcompany .
rm test/widget_test.dart
```

The second line removes the template's test, because this example has its own.

Real purchases need more than code:

1. Use an app ID that exists in App Store Connect and Play Console. `--org com.yourcompany` gives you `com.yourcompany.reusable_iap_example`.
2. Create the products with the IDs in [`store_catalog.dart`](lib/modules/store/data/store_catalog.dart), or change those IDs to yours.
3. Follow the [store setup guide](../doc/store_setup.md) for the agreements, the In-App Purchase capability and your test accounts.
4. Run it on a real device. The iOS Simulator has no store unless you add a StoreKit configuration file.

Without products in the store, the app opens and says so.

## Before you copy it

- Coins are counted on the device, which suits a demo. Anything worth real money needs [your own backend](../doc/your_own_backend.md).
- `shared_preferences` and `flutter_bloc` are this example's choices, not the package's. Use whatever your app already has.
