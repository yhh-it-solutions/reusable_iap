import 'dart:async';

import 'package:reusable_iap_example/modules/store/domain/entity/store_snapshot_entity.dart';
import 'package:reusable_iap_example/modules/store/domain/repository/store_repository.dart';

class FakeStoreRepository implements StoreRepository {
  final snapshots = StreamController<StoreSnapshotEntity>.broadcast();
  final bought = <String>[];
  int watches = 0;
  int starts = 0;
  int restores = 0;

  @override
  Stream<StoreSnapshotEntity> watch() {
    watches++;
    return snapshots.stream;
  }

  @override
  Future<void> start() async => starts++;

  @override
  Future<void> buy(String productId) async => bought.add(productId);

  @override
  Future<void> restore() async => restores++;

  @override
  void dispose() => snapshots.close();
}
