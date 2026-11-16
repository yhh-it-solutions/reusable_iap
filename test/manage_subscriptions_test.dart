import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:reusable_iap/reusable_iap.dart';

class FakeStoreKitAddition extends InAppPurchaseStoreKitPlatformAddition {
  FakeStoreKitAddition({this.error});

  final Object? error;
  int shown = 0;

  @override
  Future<void> showManageSubscriptions() async {
    shown++;
    if (error != null) {
      throw error!;
    }
  }
}

void main() {
  group('showManageSubscriptionsSheet', () {
    test('shows the sheet on iOS', () async {
      final storeKit = FakeStoreKitAddition();

      final shown = await showManageSubscriptionsSheet(
        platform: TargetPlatform.iOS,
        storeKit: storeKit,
      );

      expect(shown, isTrue);
      expect(storeKit.shown, 1);
    });

    test('reports false when StoreKit fails, so the caller can fall back',
        () async {
      final storeKit = FakeStoreKitAddition(error: Exception('iOS 14'));

      final shown = await showManageSubscriptionsSheet(
        platform: TargetPlatform.iOS,
        storeKit: storeKit,
      );

      expect(shown, isFalse);
      expect(storeKit.shown, 1);
    });

    test('does nothing on Android', () async {
      final storeKit = FakeStoreKitAddition();

      final shown = await showManageSubscriptionsSheet(
        platform: TargetPlatform.android,
        storeKit: storeKit,
      );

      expect(shown, isFalse);
      expect(storeKit.shown, 0);
    });

    test('does nothing on macOS, where StoreKit has no sheet', () async {
      final storeKit = FakeStoreKitAddition();

      final shown = await showManageSubscriptionsSheet(
        platform: TargetPlatform.macOS,
        storeKit: storeKit,
      );

      expect(shown, isFalse);
      expect(storeKit.shown, 0);
    });
  });

  group('manageSubscriptionsUri', () {
    test('opens one subscription on Android', () {
      final uri = manageSubscriptionsUri(
        productId: 'remove_ads_monthly',
        packageName: 'com.example.app',
        platform: TargetPlatform.android,
      );

      expect(
        uri.toString(),
        'https://play.google.com/store/account/subscriptions'
        '?sku=remove_ads_monthly&package=com.example.app',
      );
    });

    test('opens the list on Android without both IDs', () {
      final withoutPackage = manageSubscriptionsUri(
        productId: 'remove_ads_monthly',
        platform: TargetPlatform.android,
      );
      final withoutAny = manageSubscriptionsUri(
        platform: TargetPlatform.android,
      );

      const list = 'https://play.google.com/store/account/subscriptions';
      expect(withoutPackage.toString(), list);
      expect(withoutAny.toString(), list);
    });

    test('opens the Apple ID subscriptions list on iOS', () {
      final uri = manageSubscriptionsUri(
        productId: 'remove_ads_monthly',
        packageName: 'com.example.app',
        platform: TargetPlatform.iOS,
      );

      expect(uri.toString(), 'https://apps.apple.com/account/subscriptions');
    });
  });
}
