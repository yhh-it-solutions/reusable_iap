import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/store_snapshot_entity.dart';
import '../../domain/use_case/buy_product_use_case.dart';
import '../../domain/use_case/restore_purchases_use_case.dart';
import '../../domain/use_case/start_store_use_case.dart';
import '../../domain/use_case/watch_store_use_case.dart';

class StoreCubit extends Cubit<StoreSnapshotEntity> {
  StoreCubit({
    required WatchStoreUseCase watchStore,
    required StartStoreUseCase startStore,
    required BuyProductUseCase buyProduct,
    required RestorePurchasesUseCase restorePurchases,
  }) : _watchStore = watchStore,
       _startStore = startStore,
       _buyProduct = buyProduct,
       _restorePurchases = restorePurchases,
       super(const StoreSnapshotEntity(busy: true));

  final WatchStoreUseCase _watchStore;
  final StartStoreUseCase _startStore;
  final BuyProductUseCase _buyProduct;
  final RestorePurchasesUseCase _restorePurchases;

  StreamSubscription<StoreSnapshotEntity>? _subscription;

  Future<void> load() async {
    _subscription ??= _watchStore().listen(emit);
    await _startStore();
  }

  Future<void> buy(String productId) => _buyProduct(productId);

  Future<void> restore() => _restorePurchases();

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
