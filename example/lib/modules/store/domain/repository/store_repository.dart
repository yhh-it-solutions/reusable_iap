import '../entity/store_snapshot_entity.dart';

/// What the app needs from a store. It says nothing about how that's done, so
/// the rest of the app can't tell `reusable_iap` from a fake.
abstract interface class StoreRepository {
  Stream<StoreSnapshotEntity> watch();

  Future<void> start();

  Future<void> buy(String productId);

  Future<void> restore();

  void dispose();
}
