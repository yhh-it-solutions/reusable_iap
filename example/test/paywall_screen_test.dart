import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reusable_iap_example/modules/store/domain/entity/store_failure.dart';
import 'package:reusable_iap_example/modules/store/domain/entity/store_product_entity.dart';
import 'package:reusable_iap_example/modules/store/domain/entity/store_snapshot_entity.dart';
import 'package:reusable_iap_example/modules/store/presentation/cubit/store_cubit.dart';
import 'package:reusable_iap_example/modules/store/presentation/store_strings.dart';
import 'package:reusable_iap_example/modules/store/presentation/views/paywall_screen.dart';

import 'store_cubit_test.dart' show buildCubit;
import 'support/fake_store_repository.dart';

const _product = StoreProductEntity(
  id: 'pro_monthly',
  title: 'Pro',
  description: 'Everything, monthly',
  price: r'$4.99',
);

void main() {
  late FakeStoreRepository repository;
  late StoreCubit cubit;

  Future<void> pump(WidgetTester tester, StoreSnapshotEntity snapshot) async {
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(home: PaywallScreen()),
      ),
    );
    cubit.emit(snapshot);
    await tester.pump();
  }

  setUp(() {
    repository = FakeStoreRepository();
    cubit = buildCubit(repository);
  });
  tearDown(() => cubit.close());

  testWidgets('shows the store price and buys that product', (tester) async {
    await pump(
      tester,
      const StoreSnapshotEntity(available: true, products: [_product]),
    );

    expect(find.textContaining(r'$4.99'), findsOneWidget);

    await tester.tap(find.text(StoreStrings.buy));

    expect(repository.bought, ['pro_monthly']);
  });

  testWidgets('restore is on the screen', (tester) async {
    await pump(tester, const StoreSnapshotEntity(available: true));

    await tester.tap(find.text(StoreStrings.restore));

    expect(repository.restores, 1);
  });

  testWidgets('nothing can be pressed while the store is busy', (tester) async {
    await pump(
      tester,
      const StoreSnapshotEntity(
        available: true,
        busy: true,
        products: [_product],
      ),
    );

    await tester.tap(find.text(StoreStrings.buy));
    await tester.tap(find.text(StoreStrings.restore));

    expect(repository.bought, isEmpty);
    expect(repository.restores, 0);
  });

  testWidgets('says so when the device has no store', (tester) async {
    await pump(tester, const StoreSnapshotEntity());

    expect(find.text(StoreStrings.noStore), findsOneWidget);
  });

  testWidgets('says so when no products came back', (tester) async {
    await pump(tester, const StoreSnapshotEntity(available: true));

    expect(find.text(StoreStrings.noProducts), findsOneWidget);
  });

  testWidgets('shows what the user owns', (tester) async {
    await pump(
      tester,
      const StoreSnapshotEntity(available: true, isPremium: true, coins: 300),
    );

    expect(find.text(StoreStrings.premium), findsOneWidget);
    expect(find.text(StoreStrings.coins(300)), findsOneWidget);
  });

  testWidgets('a failure shows once, in the app\'s own words', (tester) async {
    await pump(
      tester,
      const StoreSnapshotEntity(
        available: true,
        failure: StoreFailure.purchaseFailed,
      ),
    );

    expect(
      find.text(StoreStrings.failure(StoreFailure.purchaseFailed)),
      findsOneWidget,
    );
  });
}
