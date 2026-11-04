import 'package:in_app_purchase/in_app_purchase.dart';

import 'billing_gateway.dart';
import 'iap_models.dart';

/// Default [BillingGateway] backed by Flutter's `in_app_purchase` plugin.
class FlutterBillingGateway implements BillingGateway {
  FlutterBillingGateway({
    InAppPurchase? iap,
  }) : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;
  final Map<String, ProductDetails> _productsById = <String, ProductDetails>{};

  @override
  Stream<List<BillingPurchase>> get purchaseStream {
    return _iap.purchaseStream.map(
      (purchases) => purchases
          .map(
            (purchase) => BillingPurchase(
              purchase: IapPurchase(
                productId: purchase.productID,
                status: _mapPurchaseStatus(purchase.status),
                purchaseId: purchase.purchaseID,
                transactionDate: purchase.transactionDate,
                verificationData: IapVerificationData(
                  localVerificationData:
                      purchase.verificationData.localVerificationData,
                  serverVerificationData:
                      purchase.verificationData.serverVerificationData,
                  source: purchase.verificationData.source,
                ),
                errorMessage: purchase.error?.message,
                pendingCompletePurchase: purchase.pendingCompletePurchase,
              ),
              rawPurchase: purchase,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<bool> isAvailable() {
    return _iap.isAvailable();
  }

  @override
  Future<BillingQueryResult> queryProducts(
    Set<IapProductDefinition> products,
  ) async {
    final definitionsById = {
      for (final product in products) product.id: product,
    };

    final response = await _iap.queryProductDetails(definitionsById.keys.toSet());

    // Google Play returns one entry per base plan and offer of a subscription,
    // all with the same ID. Keeping just the first means the price on screen
    // is the plan that gets bought.
    final uniqueProducts = <String, ProductDetails>{};
    for (final product in response.productDetails) {
      uniqueProducts.putIfAbsent(product.id, () => product);
    }

    // A failed refresh must not lose products that loaded earlier: they may be
    // on screen, and the player can still buy them.
    if (response.error == null || uniqueProducts.isNotEmpty) {
      _productsById
        ..clear()
        ..addAll(uniqueProducts);
    }

    return BillingQueryResult(
      products: uniqueProducts.values
          .map(
            (product) => BillingProduct(
              product: IapProduct(
                id: product.id,
                type: definitionsById[product.id]?.type ??
                    IapProductType.nonConsumable,
                title: product.title,
                description: product.description,
                price: product.price,
                currencyCode: product.currencyCode,
                rawPrice: product.rawPrice,
              ),
              rawProduct: product,
            ),
          )
          .toList(growable: false),
      notFoundIds: response.notFoundIDs.toSet(),
      errorMessage: response.error?.message,
    );
  }

  @override
  Future<void> buyConsumable(
    String productId, {
    bool autoConsume = true,
  }) async {
    final product = _requireProduct(productId);
    final purchaseParam = PurchaseParam(productDetails: product);
    final started = await _iap.buyConsumable(
      purchaseParam: purchaseParam,
      autoConsume: autoConsume,
    );
    _requireStarted(started, productId);
  }

  @override
  Future<void> buyNonConsumable(String productId) async {
    final product = _requireProduct(productId);
    final purchaseParam = PurchaseParam(productDetails: product);
    final started = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    _requireStarted(started, productId);
  }

  @override
  Future<void> restorePurchases() {
    return _iap.restorePurchases();
  }

  @override
  Future<void> completePurchase(BillingPurchase purchase) async {
    final rawPurchase = purchase.rawPurchase;
    if (rawPurchase is! PurchaseDetails) {
      throw StateError(
        'FlutterBillingGateway expected a raw PurchaseDetails instance.',
      );
    }
    await _iap.completePurchase(rawPurchase);
  }

  /// Google Play answers `false` when it couldn't open the purchase sheet, and
  /// then sends nothing on the purchase stream, so the caller has to be told.
  void _requireStarted(bool started, String productId) {
    if (!started) {
      throw StateError('The store could not start the purchase of $productId.');
    }
  }

  ProductDetails _requireProduct(String productId) {
    final product = _productsById[productId];
    if (product == null) {
      throw StateError(
        'Product $productId has not been loaded. Call loadProducts() first.',
      );
    }
    return product;
  }

  IapPurchaseStatus _mapPurchaseStatus(PurchaseStatus status) {
    switch (status) {
      case PurchaseStatus.pending:
        return IapPurchaseStatus.pending;
      case PurchaseStatus.purchased:
        return IapPurchaseStatus.purchased;
      case PurchaseStatus.restored:
        return IapPurchaseStatus.restored;
      case PurchaseStatus.canceled:
        return IapPurchaseStatus.canceled;
      case PurchaseStatus.error:
        return IapPurchaseStatus.error;
    }
  }
}
