import '../repository/store_repository.dart';

class StartStoreUseCase {
  const StartStoreUseCase(this._repository);

  final StoreRepository _repository;

  Future<void> call() => _repository.start();
}
