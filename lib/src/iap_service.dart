import 'dart:async';

import 'billing_gateway.dart';
import 'flutter_billing_gateway.dart';
import 'iap_config.dart';
import 'iap_models.dart';
import 'iap_service_api.dart';
import 'iap_state.dart';

Set<String> _emptyEntitlements(IapPurchase purchase) => const <String>{};

Future<bool> _acceptAllPurchases(IapPurchase purchase) async => true;

/// A headless IAP service built on top of [BillingGateway].
class IapService implements IapServiceApi {
  IapService({
    required this.config,
    PurchaseVerifier? verifyPurchase,
    EntitlementResolver? entitlementResolver,
    BillingGateway? gateway,
  })  : _verifyPurchase = verifyPurchase ?? _acceptAllPurchases,
        _entitlementResolver = entitlementResolver ?? _emptyEntitlements,
        _gateway = gateway ?? FlutterBillingGateway();

  final IapConfig config;
  final PurchaseVerifier _verifyPurchase;
  final EntitlementResolver _entitlementResolver;
  final BillingGateway _gateway;

  final StreamController<IapState> _stateController =
      StreamController<IapState>.broadcast();

  final Map<String, BillingProduct> _catalogById = <String, BillingProduct>{};

  StreamSubscription<List<BillingPurchase>>? _purchaseSubscription;
  IapState _state = const IapState();
  bool _disposed = false;
  Future<void>? _initializing;

  /// Starts with the current state, then every change. Joining the controller
  /// at the moment of listening means an update can't slip past in between.
  @override
  Stream<IapState> get state => Stream<IapState>.multi((listener) {
        listener.add(_state);
        final subscription = _stateController.stream.listen(
          listener.add,
          onError: listener.addError,
          onDone: listener.close,
        );
        listener.onCancel = subscription.cancel;
      });

  @override
  IapState get currentState => _state;

  void _emit(IapState newState) {
    if (_disposed) {
      return;
    }
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  /// Calls that overlap share one check of the store.
  @override
  Future<void> initialize() {
    return _initializing ??= _initialize().whenComplete(() {
      _initializing = null;
    });
  }

  Future<void> _initialize() async {
    _purchaseSubscription ??= _gateway.purchaseStream.listen(
      (purchases) {
        unawaited(
          _handlePurchaseUpdates(purchases).catchError(
            (Object error, StackTrace stackTrace) {
              _emit(
                _state.copyWith(
                  loading: false,
                  restoring: false,
                  error: IapError(
                    code: IapErrorCode.purchaseStreamFailed,
                    message: 'Purchase stream error: $error',
                  ),
                ),
              );
            },
          ),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        _emit(
          _state.copyWith(
            loading: false,
            restoring: false,
            error: IapError(
              code: IapErrorCode.purchaseStreamFailed,
              message: 'Purchase stream error: $error',
            ),
          ),
        );
      },
    );

    _emit(
      _state.copyWith(
        loading: true,
        clearError: true,
      ),
    );

    final bool available;
    try {
      available = await _gateway.isAvailable();
    } catch (error) {
      _emit(
        _state.copyWith(
          available: false,
          loading: false,
          error: IapError(
            code: IapErrorCode.storeUnavailable,
            message: 'Unable to reach the store: $error',
          ),
        ),
      );
      return;
    }

    if (!available) {
      _emit(
        _state.copyWith(
          available: false,
          initialized: true,
          loading: false,
          error: const IapError(
            code: IapErrorCode.storeUnavailable,
            message: 'In-app purchases are not available on this device.',
          ),
        ),
      );
      return;
    }

    _emit(
      _state.copyWith(
        available: true,
        initialized: true,
        loading: false,
        clearError: true,
      ),
    );
  }

  @override
  Future<List<IapProduct>> loadProducts() async {
    await _ensureInitialized();
    if (!_state.available) {
      return _state.products;
    }

    if (config.productIds.isEmpty) {
      _emit(
        _state.copyWith(
          loading: false,
          error: const IapError(
            code: IapErrorCode.emptyCatalog,
            message: 'No product IDs were configured.',
          ),
        ),
      );
      return const <IapProduct>[];
    }

    _emit(
      _state.copyWith(
        loading: true,
        clearError: true,
      ),
    );

    final BillingQueryResult response;
    try {
      response = await _gateway.queryProducts(config.products);
    } catch (error) {
      _emit(
        _state.copyWith(
          loading: false,
          error: IapError(
            code: IapErrorCode.productQueryFailed,
            message: 'Unable to load products: $error',
          ),
        ),
      );
      return _state.products;
    }

    final error = _catalogErrorFor(response);

    // A failed refresh keeps what loaded earlier: it may be on screen, and the
    // player can still buy it.
    if (error?.code == IapErrorCode.productQueryFailed &&
        response.products.isEmpty) {
      _emit(_state.copyWith(loading: false, error: error));
      return _state.products;
    }

    _catalogById
      ..clear()
      ..addEntries(
        response.products.map(
          (product) => MapEntry(product.product.id, product),
        ),
      );

    final products = response.products
        .map((product) => product.product)
        .toList(growable: false)
      ..sort((left, right) => left.id.compareTo(right.id));

    _emit(
      _state.copyWith(
        loading: false,
        products: products,
        error: error,
        clearError: error == null,
      ),
    );

    return products;
  }

  @override
  Future<void> buy(String productId) async {
    await _ensureInitialized();
    if (!_state.available) {
      return;
    }

    final product = await _loadCatalogProduct(productId);
    if (product == null) {
      _emit(
        _state.copyWith(
          loading: false,
          error: IapError(
            code: IapErrorCode.unknownProduct,
            message: 'Unknown product ID: $productId',
          ),
        ),
      );
      return;
    }

    _emit(
      _state.copyWith(
        loading: true,
        clearError: true,
        clearLastPurchase: true,
      ),
    );

    try {
      switch (product.product.type) {
        case IapProductType.consumable:
          await _gateway.buyConsumable(
            productId,
            autoConsume: config.autoConsumeConsumables,
          );
          break;
        case IapProductType.nonConsumable:
        case IapProductType.subscription:
          // The underlying Flutter plugin uses the same API for
          // non-consumables and subscriptions.
          await _gateway.buyNonConsumable(productId);
          break;
      }
    } catch (error) {
      _emit(
        _state.copyWith(
          loading: false,
          error: IapError(
            code: IapErrorCode.purchaseFailed,
            message: 'Unable to start the purchase flow for $productId: $error',
          ),
        ),
      );
    }
  }

  @override
  Future<void> restore() async {
    await _ensureInitialized();
    if (!_state.available) {
      return;
    }

    _emit(
      _state.copyWith(
        loading: true,
        restoring: true,
        clearError: true,
        clearLastPurchase: true,
      ),
    );

    try {
      await _gateway.restorePurchases();
      if (_state.restoring) {
        _emit(
          _state.copyWith(
            loading: false,
            restoring: false,
            clearError: true,
          ),
        );
      }
    } catch (error) {
      _emit(
        _state.copyWith(
          loading: false,
          restoring: false,
          error: IapError(
            code: IapErrorCode.restoreFailed,
            message: 'Unable to restore purchases: $error',
          ),
        ),
      );
    }
  }

  @override
  bool hasEntitlement(String entitlement) {
    return _state.activeEntitlements.contains(entitlement);
  }

  /// Checks again while the store is unavailable: Google Play's billing client
  /// can still be connecting at launch, and the player may have been offline.
  Future<void> _ensureInitialized() async {
    if (!_state.initialized || !_state.available) {
      await initialize();
    }
  }

  Future<BillingProduct?> _loadCatalogProduct(String productId) async {
    final cached = _catalogById[productId];
    if (cached != null) {
      return cached;
    }

    await loadProducts();
    return _catalogById[productId];
  }

  IapError? _catalogErrorFor(BillingQueryResult response) {
    if (response.errorMessage != null && response.errorMessage!.isNotEmpty) {
      return IapError(
        code: IapErrorCode.productQueryFailed,
        message: response.errorMessage!,
      );
    }

    if (response.notFoundIds.isNotEmpty) {
      final missingIds = response.notFoundIds.toList(growable: false)..sort();
      return IapError(
        code: IapErrorCode.productsNotFound,
        message: 'Products not found: ${missingIds.join(', ')}',
      );
    }

    return null;
  }

  Future<void> _handlePurchaseUpdates(
    List<BillingPurchase> purchaseDetailsList,
  ) async {
    for (final purchase in purchaseDetailsList) {
      final normalizedPurchase = _normalizePurchase(purchase.purchase);
      final normalizedBillingPurchase =
          purchase.copyWith(purchase: normalizedPurchase);

      switch (normalizedPurchase.status) {
        case IapPurchaseStatus.pending:
          _emit(
            _state.copyWith(
              loading: true,
              restoring: normalizedPurchase.isRestored && _state.restoring,
              lastPurchase: normalizedPurchase,
              clearError: true,
            ),
          );
          break;
        case IapPurchaseStatus.error:
          _emit(
            _state.copyWith(
              loading: false,
              restoring: false,
              lastPurchase: normalizedPurchase,
              error: IapError(
                code: IapErrorCode.purchaseFailed,
                message:
                    normalizedPurchase.errorMessage ?? 'Purchase failed.',
              ),
            ),
          );
          await _completePurchaseIfNeeded(normalizedBillingPurchase);
          break;
        case IapPurchaseStatus.canceled:
          _emit(
            _state.copyWith(
              loading: false,
              restoring: false,
              lastPurchase: normalizedPurchase,
              error: IapError(
                code: IapErrorCode.purchaseCancelled,
                message:
                    normalizedPurchase.errorMessage ?? 'Purchase was cancelled.',
              ),
            ),
          );
          await _completePurchaseIfNeeded(normalizedBillingPurchase);
          break;
        case IapPurchaseStatus.purchased:
        case IapPurchaseStatus.restored:
          await _processSuccessfulPurchase(normalizedBillingPurchase);
          break;
      }
    }
  }

  IapPurchase _normalizePurchase(IapPurchase purchase) {
    final productType =
        purchase.productType ?? config.productTypeFor(purchase.productId);
    return purchase.copyWith(productType: productType);
  }

  /// A purchase that fails verification is left uncompleted on purpose: the
  /// store sends it again, so a passing check can still deliver it, and Google
  /// Play refunds it if it never gets acknowledged.
  Future<void> _processSuccessfulPurchase(BillingPurchase purchase) async {
    final normalizedPurchase = purchase.purchase;

    try {
      final isValid = await _verifyPurchase(normalizedPurchase);
      if (!isValid) {
        _emit(
          _state.copyWith(
            loading: false,
            restoring: false,
            lastPurchase: normalizedPurchase,
            error: IapError(
              code: IapErrorCode.verificationFailed,
              message:
                  'Purchase verification failed for ${normalizedPurchase.productId}.',
            ),
          ),
        );
        return;
      }

      final entitlements = {
        ..._state.activeEntitlements,
        ..._entitlementResolver(normalizedPurchase),
      };

      _emit(
        _state.copyWith(
          loading: false,
          restoring: false,
          activeEntitlements: entitlements,
          lastPurchase: normalizedPurchase,
          clearError: true,
        ),
      );

      await _completePurchaseIfNeeded(purchase);
    } catch (error) {
      _emit(
        _state.copyWith(
          loading: false,
          restoring: false,
          lastPurchase: normalizedPurchase,
          error: IapError(
            code: IapErrorCode.verificationFailed,
            message: 'Purchase verification error: $error',
          ),
        ),
      );
    }
  }

  Future<void> _completePurchaseIfNeeded(BillingPurchase purchase) async {
    if (!purchase.purchase.pendingCompletePurchase) {
      return;
    }

    try {
      await _gateway.completePurchase(purchase);
    } catch (error) {
      _emit(
        _state.copyWith(
          error: IapError(
            code: IapErrorCode.purchaseCompletionFailed,
            message:
                'Purchase completed but acknowledgement failed: $error',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_purchaseSubscription?.cancel());
    _purchaseSubscription = null;
    _catalogById.clear();
    _stateController.close();
  }
}
