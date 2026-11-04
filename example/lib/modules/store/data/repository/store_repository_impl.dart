import 'dart:async';

import 'package:reusable_iap/reusable_iap.dart';

import '../../domain/entity/store_failure.dart';
import '../../domain/entity/store_product_entity.dart';
import '../../domain/entity/store_snapshot_entity.dart';
import '../../domain/repository/store_repository.dart';
import '../store_cache.dart';
import '../store_catalog.dart';

/// Turns `reusable_iap`'s state into the app's own [StoreSnapshotEntity].
class StoreRepositoryImpl implements StoreRepository {
  StoreRepositoryImpl({
    required IapServiceApi iap,
    required StoreCache cache,
    Duration restoreSettleTime = const Duration(seconds: 2),
  }) : _iap = iap,
       _cache = cache,
       _restoreSettleTime = restoreSettleTime;

  final IapServiceApi _iap;
  final StoreCache _cache;
  final Duration _restoreSettleTime;

  final _snapshots = StreamController<StoreSnapshotEntity>.broadcast();
  final _deliveredPurchases = <String>{};
  StreamSubscription<IapState>? _subscription;

  @override
  Stream<StoreSnapshotEntity> watch() => _snapshots.stream;

  @override
  Future<void> start() async {
    _subscription ??= _iap.state.listen(_onIapState);

    await _iap.initialize();
    // "No store here" says nothing about the user: keep what was saved.
    if (!_iap.currentState.available) return;

    await _iap.loadProducts();
    await _checkAccess();
  }

  @override
  Future<void> buy(String productId) => _iap.buy(productId);

  @override
  Future<void> restore() => _iap.restore();

  @override
  void dispose() {
    _subscription?.cancel();
    _snapshots.close();
    _iap.dispose();
  }

  /// Access lives in memory, so each launch asks the store again. That's how an
  /// expired or refunded subscription loses access.
  Future<void> _checkAccess() async {
    await _iap.restore();

    // restore() returns once the request is sent. Purchases arrive just after.
    await Future<void>.delayed(_restoreSettleTime);

    // "Couldn't ask" is not "doesn't own it": keep what was saved.
    if (_iap.currentState.error != null) return;

    await _cache.saveIsPremium(_iap.hasEntitlement(StoreCatalog.premium));
    _publish(_iap.currentState);
  }

  void _onIapState(IapState state) {
    _deliverCoins(state.lastPurchase);
    if (state.activeEntitlements.contains(StoreCatalog.premium)) {
      unawaited(_cache.saveIsPremium(true));
    }
    _publish(state);
  }

  /// `lastPurchase` repeats on every later state, and a store can send the same
  /// purchase twice, so each one is counted once.
  ///
  /// A local balance suits a demo. Coins worth real money belong on your server.
  void _deliverCoins(IapPurchase? purchase) {
    if (purchase == null ||
        purchase.status != IapPurchaseStatus.purchased ||
        purchase.productId != StoreCatalog.coins100) {
      return;
    }

    // Play's order ID can be missing; its purchase token is always there.
    final orderId = purchase.purchaseId;
    final key = orderId == null || orderId.isEmpty
        ? purchase.verificationData?.serverVerificationData
        : orderId;
    if (key == null || !_deliveredPurchases.add(key)) return;

    unawaited(_cache.saveCoins(_cache.coins + StoreCatalog.coinsPerPack));
  }

  void _publish(IapState state) {
    if (_snapshots.isClosed) return;
    _snapshots.add(
      StoreSnapshotEntity(
        available: state.available,
        busy: state.loading,
        products: state.products.map(_toEntity).toList(growable: false),
        isPremium:
            state.activeEntitlements.contains(StoreCatalog.premium) ||
            _cache.isPremium,
        coins: _cache.coins,
        failure: _toFailure(state.error?.code),
      ),
    );
  }

  StoreProductEntity _toEntity(IapProduct product) => StoreProductEntity(
    id: product.id,
    title: product.title,
    description: product.description,
    price: product.price,
  );

  StoreFailure? _toFailure(IapErrorCode? code) => switch (code) {
    // Closing the payment sheet isn't a failure.
    null || IapErrorCode.purchaseCancelled => null,
    IapErrorCode.storeUnavailable => StoreFailure.unavailable,
    IapErrorCode.emptyCatalog ||
    IapErrorCode.productsNotFound ||
    IapErrorCode.unknownProduct => StoreFailure.itemMissing,
    IapErrorCode.productQueryFailed => StoreFailure.noConnection,
    IapErrorCode.purchaseFailed ||
    IapErrorCode.purchaseStreamFailed => StoreFailure.purchaseFailed,
    IapErrorCode.verificationFailed => StoreFailure.notConfirmed,
    IapErrorCode.purchaseCompletionFailed => StoreFailure.stillFinishing,
    IapErrorCode.restoreFailed => StoreFailure.restoreFailed,
  };
}
