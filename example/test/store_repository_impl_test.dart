import 'package:flutter_test/flutter_test.dart';
import 'package:reusable_iap/reusable_iap.dart';
import 'package:reusable_iap_example/modules/store/data/repository/store_repository_impl.dart';
import 'package:reusable_iap_example/modules/store/data/store_cache.dart';
import 'package:reusable_iap_example/modules/store/data/store_catalog.dart';
import 'package:reusable_iap_example/modules/store/domain/entity/store_failure.dart';
import 'package:reusable_iap_example/modules/store/domain/entity/store_snapshot_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_billing_gateway.dart';

const _monthly = IapPurchase(
  productId: StoreCatalog.proMonthly,
  status: IapPurchaseStatus.purchased,
  purchaseId: 'order-1',
  pendingCompletePurchase: true,
);

IapPurchase _coins(String purchaseId) => IapPurchase(
  productId: StoreCatalog.coins100,
  status: IapPurchaseStatus.purchased,
  purchaseId: purchaseId,
  pendingCompletePurchase: true,
);

void main() {
  late FakeBillingGateway gateway;
  late StoreCache cache;
  late StoreRepositoryImpl repository;
  late List<StoreSnapshotEntity> snapshots;

  Future<void> build({Map<String, Object> saved = const {}}) async {
    SharedPreferences.setMockInitialValues(saved);
    cache = StoreCache(await SharedPreferences.getInstance());
    repository = StoreRepositoryImpl(
      iap: IapService(
        config: StoreCatalog.config,
        entitlementResolver: StoreCatalog.entitlementsFor,
        gateway: gateway,
      ),
      cache: cache,
      restoreSettleTime: Duration.zero,
    );
    snapshots = [];
    repository.watch().listen(snapshots.add);
  }

  Future<void> startAndSettle() async {
    await repository.start();
    await pumpEventQueue();
  }

  setUp(() => gateway = FakeBillingGateway());
  tearDown(() => repository.dispose());

  test('products reach the app as its own entities', () async {
    gateway.products = const [
      IapProduct(
        id: StoreCatalog.lifetimeUnlock,
        type: IapProductType.nonConsumable,
        title: 'Lifetime',
        description: 'Forever',
        price: r'$9.99',
      ),
    ];
    await build();

    await startAndSettle();

    final product = snapshots.last.products.single;
    expect(product.id, StoreCatalog.lifetimeUnlock);
    expect(product.price, r'$9.99');
  });

  test('buying a plan turns premium on, saves it and completes it', () async {
    await build();
    await startAndSettle();

    gateway.deliver(_monthly);
    await pumpEventQueue();

    expect(snapshots.last.isPremium, isTrue);
    expect(cache.isPremium, isTrue);
    expect(gateway.completed, [StoreCatalog.proMonthly]);
  });

  group('the check on launch', () {
    test('keeps premium when the store still has the purchase', () async {
      gateway.owned = const [_monthly];
      await build(saved: {'store.is_premium': true});

      await startAndSettle();

      expect(snapshots.last.isPremium, isTrue);
      expect(cache.isPremium, isTrue);
    });

    test('turns premium off when the store no longer has it', () async {
      await build(saved: {'store.is_premium': true});

      await startAndSettle();

      expect(snapshots.last.isPremium, isFalse);
      expect(cache.isPremium, isFalse);
    });

    test('keeps the saved value when there is no store', () async {
      gateway.available = false;
      await build(saved: {'store.is_premium': true});

      await startAndSettle();

      expect(snapshots.last.available, isFalse);
      expect(snapshots.last.isPremium, isTrue);
      expect(cache.isPremium, isTrue);
    });

    test('keeps the saved value when the restore fails', () async {
      gateway.restoreError = StateError('offline');
      await build(saved: {'store.is_premium': true});

      await startAndSettle();

      expect(snapshots.last.failure, StoreFailure.restoreFailed);
      expect(snapshots.last.isPremium, isTrue);
      expect(cache.isPremium, isTrue);
    });
  });

  group('coins', () {
    test('a pack is counted once, however often it comes back', () async {
      await build();
      await startAndSettle();

      gateway.deliver(_coins('order-7'));
      gateway.deliver(_coins('order-7'));
      await pumpEventQueue();

      expect(snapshots.last.coins, StoreCatalog.coinsPerPack);
      expect(cache.coins, StoreCatalog.coinsPerPack);
    });

    test(
      'two packs are counted twice, and pile onto the saved balance',
      () async {
        await build(saved: {'store.coins': 50});
        await startAndSettle();

        gateway.deliver(_coins('order-7'));
        gateway.deliver(_coins('order-8'));
        await pumpEventQueue();

        expect(snapshots.last.coins, 50 + 2 * StoreCatalog.coinsPerPack);
      },
    );

    test('with no order ID, the purchase token tells packs apart', () async {
      await build();
      await startAndSettle();

      for (final token in ['token-a', 'token-a', 'token-b']) {
        gateway.deliver(
          IapPurchase(
            productId: StoreCatalog.coins100,
            status: IapPurchaseStatus.purchased,
            purchaseId: '',
            verificationData: IapVerificationData(
              localVerificationData: '',
              serverVerificationData: token,
              source: 'google_play',
            ),
          ),
        );
      }
      await pumpEventQueue();

      expect(snapshots.last.coins, 2 * StoreCatalog.coinsPerPack);
    });

    test('a pack that is still pending gives nothing', () async {
      await build();
      await startAndSettle();

      gateway.deliver(
        const IapPurchase(
          productId: StoreCatalog.coins100,
          status: IapPurchaseStatus.pending,
          purchaseId: 'order-9',
        ),
      );
      await pumpEventQueue();

      expect(snapshots.last.coins, 0);
    });
  });

  group('failures', () {
    test('closing the payment sheet is not a failure', () async {
      await build();
      await startAndSettle();

      gateway.deliver(
        const IapPurchase(
          productId: StoreCatalog.proMonthly,
          status: IapPurchaseStatus.canceled,
        ),
      );
      await pumpEventQueue();

      expect(snapshots.last.failure, isNull);
    });

    test('a failed payment is reported in the app\'s own terms', () async {
      await build();
      await startAndSettle();

      gateway.deliver(
        const IapPurchase(
          productId: StoreCatalog.proMonthly,
          status: IapPurchaseStatus.error,
        ),
      );
      await pumpEventQueue();

      expect(snapshots.last.failure, StoreFailure.purchaseFailed);
      expect(snapshots.last.isPremium, isFalse);
    });
  });
}
