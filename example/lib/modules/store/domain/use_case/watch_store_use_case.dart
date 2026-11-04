import '../entity/store_snapshot_entity.dart';
import '../repository/store_repository.dart';

class WatchStoreUseCase {
  const WatchStoreUseCase(this._repository);

  final StoreRepository _repository;

  Stream<StoreSnapshotEntity> call() => _repository.watch();
}
