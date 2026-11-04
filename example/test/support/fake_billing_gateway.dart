import 'dart:async';

import 'package:reusable_iap/reusable_iap.dart';

/// Stands in for the App Store and Google Play.
class FakeBillingGateway implements BillingGateway {
  final purchases = StreamController<List<BillingPurchase>>.broadcast();
  final completed = <String>[];

  bool available = true;
  Object? restoreError;
  List<IapProduct> products = const [];

  /// What the store hands back when asked to restore.
  List<IapPurchase> owned = const [];

  void deliver(IapPurchase purchase) =>
      purchases.add([BillingPurchase(purchase: purchase)]);

  @override
  Stream<List<BillingPurchase>> get purchaseStream => purchases.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<BillingQueryResult> queryProducts(
    Set<IapProductDefinition> products,
  ) async {
    return BillingQueryResult(
      products: [
        for (final product in this.products) BillingProduct(product: product),
      ],
    );
  }

  @override
  Future<void> buyConsumable(
    String productId, {
    bool autoConsume = true,
  }) async {}

  @override
  Future<void> buyNonConsumable(String productId) async {}

  @override
  Future<void> restorePurchases() async {
    final error = restoreError;
    if (error != null) throw error;
    owned.forEach(deliver);
  }

  @override
  Future<void> completePurchase(BillingPurchase purchase) async {
    completed.add(purchase.purchase.productId);
  }
}
