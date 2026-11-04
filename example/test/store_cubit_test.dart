import 'package:flutter_test/flutter_test.dart';
import 'package:reusable_iap_example/modules/store/domain/entity/store_snapshot_entity.dart';
import 'package:reusable_iap_example/modules/store/domain/use_case/buy_product_use_case.dart';
import 'package:reusable_iap_example/modules/store/domain/use_case/restore_purchases_use_case.dart';
import 'package:reusable_iap_example/modules/store/domain/use_case/start_store_use_case.dart';
import 'package:reusable_iap_example/modules/store/domain/use_case/watch_store_use_case.dart';
import 'package:reusable_iap_example/modules/store/presentation/cubit/store_cubit.dart';

import 'support/fake_store_repository.dart';

StoreCubit buildCubit(FakeStoreRepository repository) => StoreCubit(
  watchStore: WatchStoreUseCase(repository),
  startStore: StartStoreUseCase(repository),
  buyProduct: BuyProductUseCase(repository),
  restorePurchases: RestorePurchasesUseCase(repository),
);

void main() {
  late FakeStoreRepository repository;
  late StoreCubit cubit;

  setUp(() {
    repository = FakeStoreRepository();
    cubit = buildCubit(repository);
  });
  tearDown(() => cubit.close());

  test('starts out busy, before the store has answered', () {
    expect(cubit.state.busy, isTrue);
  });

  test('load starts the store and follows what it reports', () async {
    await cubit.load();

    repository.snapshots.add(const StoreSnapshotEntity(isPremium: true));
    await pumpEventQueue();

    expect(repository.starts, 1);
    expect(cubit.state.isPremium, isTrue);
  });

  test('loading twice does not listen twice', () async {
    await cubit.load();
    await cubit.load();

    expect(repository.watches, 1);
  });

  test('buy and restore reach the repository', () async {
    await cubit.buy('pro_monthly');
    await cubit.restore();

    expect(repository.bought, ['pro_monthly']);
    expect(repository.restores, 1);
  });

  test('closing stops listening', () async {
    await cubit.load();

    await cubit.close();

    expect(repository.snapshots.hasListener, isFalse);
  });
}
