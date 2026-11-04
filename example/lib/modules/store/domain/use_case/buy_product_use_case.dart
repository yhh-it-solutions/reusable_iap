import '../repository/store_repository.dart';

class BuyProductUseCase {
  const BuyProductUseCase(this._repository);

  final StoreRepository _repository;

  Future<void> call(String productId) => _repository.buy(productId);
}
