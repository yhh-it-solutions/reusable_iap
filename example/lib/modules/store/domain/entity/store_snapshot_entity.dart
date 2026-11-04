import 'package:equatable/equatable.dart';

import 'store_failure.dart';
import 'store_product_entity.dart';

/// Everything a screen needs to know about the store right now.
class StoreSnapshotEntity extends Equatable {
  const StoreSnapshotEntity({
    this.available = false,
    this.busy = false,
    this.products = const [],
    this.isPremium = false,
    this.coins = 0,
    this.failure,
  });

  final bool available;
  final bool busy;
  final List<StoreProductEntity> products;
  final bool isPremium;
  final int coins;
  final StoreFailure? failure;

  @override
  List<Object?> get props => [
    available,
    busy,
    products,
    isPremium,
    coins,
    failure,
  ];
}
