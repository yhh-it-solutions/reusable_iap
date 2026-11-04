import '../repository/store_repository.dart';

class RestorePurchasesUseCase {
  const RestorePurchasesUseCase(this._repository);

  final StoreRepository _repository;

  Future<void> call() => _repository.restore();
}
