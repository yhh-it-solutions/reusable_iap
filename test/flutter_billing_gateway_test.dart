import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:reusable_iap/reusable_iap.dart';

class FakeInAppPurchase implements InAppPurchase {
  ProductDetailsResponse response = ProductDetailsResponse(
    productDetails: const [],
    notFoundIDs: const [],
  );
  bool buyResult = true;
  final List<ProductDetails> bought = <ProductDetails>[];

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async => response;

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    bought.add(purchaseParam.productDetails);
    return buyResult;
  }

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    bought.add(purchaseParam.productDetails);
    return buyResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProductDetails details(String id, String price) => ProductDetails(
  id: id,
  title: '$id title',
  description: '$id description',
  price: price,
  rawPrice: 1,
  currencyCode: 'USD',
);

void main() {
  final catalog = {const IapProductDefinition.subscription('pro_monthly')};
  late FakeInAppPurchase iap;
  late FlutterBillingGateway gateway;

  setUp(() {
    iap = FakeInAppPurchase();
    gateway = FlutterBillingGateway(iap: iap);
  });

  // Google Play returns one entry per base plan and offer.
  test('a subscription with several offers is one product, and the price '
      'shown is the plan that gets bought', () async {
    iap.response = ProductDetailsResponse(
      productDetails: [
        details('pro_monthly', r'$1.00'),
        details('pro_monthly', r'$2.00'),
      ],
      notFoundIDs: const [],
    );

    final result = await gateway.queryProducts(catalog);
    await gateway.buyNonConsumable('pro_monthly');

    expect(result.products, hasLength(1));
    expect(result.products.single.product.price, r'$1.00');
    expect(iap.bought.single.price, r'$1.00');
  });

  test('buying throws when the store refuses to start', () async {
    iap
      ..response = ProductDetailsResponse(
        productDetails: [details('pro_monthly', r'$1.00')],
        notFoundIDs: const [],
      )
      ..buyResult = false;
    await gateway.queryProducts(catalog);

    expect(gateway.buyNonConsumable('pro_monthly'), throwsStateError);
    expect(gateway.buyConsumable('pro_monthly'), throwsStateError);
  });

  test('a failed refresh can still buy what loaded earlier', () async {
    iap.response = ProductDetailsResponse(
      productDetails: [details('pro_monthly', r'$1.00')],
      notFoundIDs: const [],
    );
    await gateway.queryProducts(catalog);

    iap.response = ProductDetailsResponse(
      productDetails: const [],
      notFoundIDs: const ['pro_monthly'],
      error: IAPError(source: 'test', code: 'offline', message: 'offline'),
    );
    final result = await gateway.queryProducts(catalog);
    await gateway.buyNonConsumable('pro_monthly');

    expect(result.errorMessage, 'offline');
    expect(iap.bought.single.id, 'pro_monthly');
  });
}
