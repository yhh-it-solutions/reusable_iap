import 'package:equatable/equatable.dart';

/// Something the app sells, in the app's own terms.
class StoreProductEntity extends Equatable {
  const StoreProductEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
  });

  final String id;
  final String title;
  final String description;

  /// Already localized by the store, such as "$4.99" or "रू499".
  final String price;

  @override
  List<Object?> get props => [id, title, description, price];
}
