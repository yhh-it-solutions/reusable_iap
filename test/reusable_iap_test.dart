import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:reusable_iap/reusable_iap.dart';

class FakeBillingGateway implements BillingGateway {
  final StreamController<List<BillingPurchase>> _purchaseController =
      StreamController<List<BillingPurchase>>.broadcast();

  bool available = true;
  Object? availabilityError;
  Object? queryError;
  Object? buyError;
  int availabilityChecks = 0;
  BillingQueryResult queryResult = const BillingQueryResult();
  final List<String> consumableBuys = <String>[];
  final List<String> nonConsumableBuys = <String>[];
  final List<String> completedProducts = <String>[];
  int restoreCalls = 0;

  @override
  Stream<List<BillingPurchase>> get purchaseStream => _purchaseController.stream;

  @override
  Future<bool> isAvailable() async {
    availabilityChecks += 1;
    final error = availabilityError;
    if (error != null) throw error;
    return available;
  }

  @override
  Future<BillingQueryResult> queryProducts(
    Set<IapProductDefinition> products,
  ) async {
    final error = queryError;
    if (error != null) throw error;
    return queryResult;
  }

  @override
  Future<void> buyConsumable(
    String productId, {
    bool autoConsume = true,
  }) async {
    consumableBuys.add(productId);
  }

  @override
  Future<void> buyNonConsumable(String productId) async {
    final error = buyError;
    if (error != null) throw error;
    nonConsumableBuys.add(productId);
  }

  @override
  Future<void> restorePurchases() async {
    restoreCalls += 1;
  }

  @override
  Future<void> completePurchase(BillingPurchase purchase) async {
    completedProducts.add(purchase.purchase.productId);
  }

  void emitPurchases(List<BillingPurchase> purchases) {
    _purchaseController.add(purchases);
  }

  Future<void> dispose() async {
    await _purchaseController.close();
  }
}

BillingProduct billingProduct(
  String id,
  IapProductType type,
) {
  return BillingProduct(
    product: IapProduct(
      id: id,
      type: type,
      title: '$id title',
      description: '$id description',
      price: '\$4.99',
      currencyCode: 'USD',
      rawPrice: 4.99,
    ),
  );
}

BillingPurchase billingPurchase(
  String productId,
  IapPurchaseStatus status, {
  bool pendingCompletePurchase = false,
  String? errorMessage,
}) {
  return BillingPurchase(
    purchase: IapPurchase(
      productId: productId,
      status: status,
      pendingCompletePurchase: pendingCompletePurchase,
      errorMessage: errorMessage,
      verificationData: const IapVerificationData(
        localVerificationData: 'local',
        serverVerificationData: 'server',
        source: 'test',
      ),
    ),
  );
}

void main() {
  late FakeBillingGateway gateway;

  setUp(() {
    gateway = FakeBillingGateway();
  });

  tearDown(() async {
    await gateway.dispose();
  });

  test('initialize reflects store unavailability', () async {
    gateway.available = false;

    final service = IapService(
      config: IapConfig(
        products: {
          const IapProductDefinition.subscription('pro_monthly'),
        },
      ),
      gateway: gateway,
    );

    final initialState = await service.state.first;
    expect(initialState, service.currentState);

    await service.initialize();

    expect(service.currentState.initialized, isTrue);
    expect(service.currentState.available, isFalse);
    expect(service.currentState.error?.code, IapErrorCode.storeUnavailable);

    service.dispose();
  });

  test('loadProducts normalizes the catalog and buy routes by product type',
      () async {
    gateway.queryResult = BillingQueryResult(
      products: [
        billingProduct('coins_100', IapProductType.consumable),
        billingProduct('lifetime_unlock', IapProductType.nonConsumable),
        billingProduct('pro_monthly', IapProductType.subscription),
      ],
    );

    final service = IapService(
      config: IapConfig(
        consumableIds: {'coins_100'},
        nonConsumableIds: {'lifetime_unlock'},
        subscriptionIds: {'pro_monthly'},
      ),
      gateway: gateway,
    );

    await service.initialize();
    final products = await service.loadProducts();

    expect(products, hasLength(3));
    expect(
      products
          .firstWhere((product) => product.id == 'pro_monthly')
          .isSubscription,
      isTrue,
    );

    await service.buy('coins_100');
    await service.buy('lifetime_unlock');
    await service.buy('pro_monthly');

    expect(gateway.consumableBuys, ['coins_100']);
    expect(
      gateway.nonConsumableBuys,
      ['lifetime_unlock', 'pro_monthly'],
    );

    service.dispose();
  });

  test('purchased and restored updates grant entitlements and complete purchase',
      () async {
    gateway.queryResult = BillingQueryResult(
      products: [
        billingProduct('pro_monthly', IapProductType.subscription),
        billingProduct('lifetime_unlock', IapProductType.nonConsumable),
      ],
    );

    final service = IapService(
      config: IapConfig(
        subscriptionIds: {'pro_monthly'},
        nonConsumableIds: {'lifetime_unlock'},
      ),
      entitlementResolver: (purchase) {
        if (purchase.productId == 'pro_monthly' ||
            purchase.productId == 'lifetime_unlock') {
          return {'premium'};
        }
        return const <String>{};
      },
      gateway: gateway,
    );

    await service.initialize();
    await service.loadProducts();

    gateway.emitPurchases([
      billingPurchase(
        'pro_monthly',
        IapPurchaseStatus.purchased,
        pendingCompletePurchase: true,
      ),
      billingPurchase(
        'lifetime_unlock',
        IapPurchaseStatus.restored,
        pendingCompletePurchase: true,
      ),
    ]);

    await Future<void>.delayed(Duration.zero);

    expect(service.hasEntitlement('premium'), isTrue);
    expect(
      service.currentState.lastPurchase?.status,
      IapPurchaseStatus.restored,
    );
    expect(
      gateway.completedProducts,
      ['pro_monthly', 'lifetime_unlock'],
    );

    service.dispose();
  });

  test('verification failure blocks entitlements and acknowledgement', () async {
    gateway.queryResult = BillingQueryResult(
      products: [
        billingProduct('pro_monthly', IapProductType.subscription),
      ],
    );

    final service = IapService(
      config: IapConfig(
        subscriptionIds: {'pro_monthly'},
      ),
      verifyPurchase: (_) async => false,
      entitlementResolver: (_) => {'premium'},
      gateway: gateway,
    );

    await service.initialize();
    await service.loadProducts();

    gateway.emitPurchases([
      billingPurchase(
        'pro_monthly',
        IapPurchaseStatus.purchased,
        pendingCompletePurchase: true,
      ),
    ]);

    await Future<void>.delayed(Duration.zero);

    expect(service.hasEntitlement('premium'), isFalse);
    expect(
      service.currentState.error?.code,
      IapErrorCode.verificationFailed,
    );
    expect(gateway.completedProducts, isEmpty);

    service.dispose();
  });

  test('canceled and failed purchases surface normalized errors', () async {
    final service = IapService(
      config: IapConfig(
        nonConsumableIds: {'lifetime_unlock'},
      ),
      gateway: gateway,
    );

    await service.initialize();

    gateway.emitPurchases([
      billingPurchase(
        'lifetime_unlock',
        IapPurchaseStatus.canceled,
      ),
    ]);

    await Future<void>.delayed(Duration.zero);

    expect(
      service.currentState.error?.code,
      IapErrorCode.purchaseCancelled,
    );

    gateway.emitPurchases([
      billingPurchase(
        'lifetime_unlock',
        IapPurchaseStatus.error,
        errorMessage: 'Billing unavailable',
      ),
    ]);

    await Future<void>.delayed(Duration.zero);

    expect(
      service.currentState.error?.code,
      IapErrorCode.purchaseFailed,
    );
    expect(
      service.currentState.error?.message,
      'Billing unavailable',
    );

    service.dispose();
  });

  test('restore delegates to the gateway and resets restoring state', () async {
    final service = IapService(
      config: IapConfig(
        subscriptionIds: {'pro_monthly'},
      ),
      gateway: gateway,
    );

    await service.initialize();
    await service.restore();

    expect(gateway.restoreCalls, 1);
    expect(service.currentState.restoring, isFalse);
    expect(service.currentState.loading, isFalse);

    service.dispose();
  });

  test('failed and cancelled purchases are completed when the store asks',
      () async {
    final service = IapService(
      config: IapConfig(subscriptionIds: {'pro_monthly'}),
      gateway: gateway,
    );
    await service.initialize();

    gateway.emitPurchases([
      billingPurchase(
        'pro_monthly',
        IapPurchaseStatus.error,
        pendingCompletePurchase: true,
      ),
      billingPurchase(
        'pro_monthly',
        IapPurchaseStatus.canceled,
        pendingCompletePurchase: true,
      ),
    ]);
    await pumpEventQueue();

    expect(gateway.completedProducts, ['pro_monthly', 'pro_monthly']);
    expect(service.hasEntitlement('premium'), isFalse);

    service.dispose();
  });

  test('a purchase the store refuses to start is reported, not left loading',
      () async {
    gateway
      ..queryResult = BillingQueryResult(
        products: [
          billingProduct('pro_monthly', IapProductType.subscription),
        ],
      )
      ..buyError = StateError('refused');
    final service = IapService(
      config: IapConfig(subscriptionIds: {'pro_monthly'}),
      gateway: gateway,
    );
    await service.initialize();
    await service.loadProducts();

    await service.buy('pro_monthly');

    expect(service.currentState.loading, isFalse);
    expect(service.currentState.error?.code, IapErrorCode.purchaseFailed);

    service.dispose();
  });

  test('an error checking the store is reported and can be retried', () async {
    gateway.availabilityError = StateError('no billing client');
    final service = IapService(
      config: IapConfig(subscriptionIds: {'pro_monthly'}),
      gateway: gateway,
    );

    await service.initialize();

    expect(service.currentState.loading, isFalse);
    expect(service.currentState.available, isFalse);
    expect(service.currentState.error?.code, IapErrorCode.storeUnavailable);

    gateway.availabilityError = null;
    await service.loadProducts();

    expect(service.currentState.available, isTrue);

    service.dispose();
  });

  test('a store that was unavailable recovers on the next call', () async {
    gateway
      ..available = false
      ..queryResult = BillingQueryResult(
        products: [
          billingProduct('pro_monthly', IapProductType.subscription),
        ],
      );
    final service = IapService(
      config: IapConfig(subscriptionIds: {'pro_monthly'}),
      gateway: gateway,
    );
    await service.initialize();
    expect(await service.loadProducts(), isEmpty);

    gateway.available = true;
    final products = await service.loadProducts();

    expect(products.map((product) => product.id), ['pro_monthly']);
    expect(service.currentState.error, isNull);

    service.dispose();
  });

  test('an error loading products is reported, not thrown', () async {
    gateway.queryError = StateError('offline');
    final service = IapService(
      config: IapConfig(subscriptionIds: {'pro_monthly'}),
      gateway: gateway,
    );
    await service.initialize();

    expect(await service.loadProducts(), isEmpty);

    expect(service.currentState.loading, isFalse);
    expect(service.currentState.error?.code, IapErrorCode.productQueryFailed);

    service.dispose();
  });

  test('a failed refresh keeps the products that loaded earlier', () async {
    gateway.queryResult = BillingQueryResult(
      products: [
        billingProduct('pro_monthly', IapProductType.subscription),
      ],
    );
    final service = IapService(
      config: IapConfig(subscriptionIds: {'pro_monthly'}),
      gateway: gateway,
    );
    await service.initialize();
    await service.loadProducts();

    gateway.queryResult = const BillingQueryResult(errorMessage: 'offline');
    final products = await service.loadProducts();

    expect(products.map((product) => product.id), ['pro_monthly']);
    expect(service.currentState.error?.code, IapErrorCode.productQueryFailed);

    await service.buy('pro_monthly');
    expect(gateway.nonConsumableBuys, ['pro_monthly']);

    service.dispose();
  });

  test('overlapping calls share one check of the store', () async {
    final service = IapService(
      config: IapConfig(subscriptionIds: {'pro_monthly'}),
      gateway: gateway,
    );

    await Future.wait([service.initialize(), service.initialize()]);
    expect(gateway.availabilityChecks, 1);

    // Finished, so a later call really checks again.
    await service.initialize();
    expect(gateway.availabilityChecks, 2);

    service.dispose();
  });
}
