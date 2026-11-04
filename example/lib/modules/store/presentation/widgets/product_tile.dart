import 'package:flutter/material.dart';

import '../../domain/entity/store_product_entity.dart';
import '../store_strings.dart';

class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.product, required this.onBuy});

  final StoreProductEntity product;

  /// Null while the store is busy, which disables the button.
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(product.title),
        subtitle: Text('${product.description}\n${product.price}'),
        isThreeLine: true,
        trailing: FilledButton(
          onPressed: onBuy,
          child: const Text(StoreStrings.buy),
        ),
      ),
    );
  }
}
