import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/store_snapshot_entity.dart';
import '../cubit/store_cubit.dart';
import '../store_strings.dart';
import '../widgets/access_card.dart';
import '../widgets/product_tile.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<StoreCubit, StoreSnapshotEntity>(
      listenWhen: (previous, current) =>
          current.failure != null && previous.failure != current.failure,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(StoreStrings.failure(state.failure!))),
        );
      },
      child: const PaywallView(),
    );
  }
}

class PaywallView extends StatelessWidget {
  const PaywallView({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StoreCubit>();
    final store = context.watch<StoreCubit>().state;
    final canUseStore = store.available && !store.busy;

    return Scaffold(
      appBar: AppBar(title: const Text(StoreStrings.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (store.busy) const LinearProgressIndicator(),
          AccessCard(isPremium: store.isPremium, coins: store.coins),
          if (!store.available && !store.busy)
            const Text(StoreStrings.noStore)
          else if (store.products.isEmpty && !store.busy)
            const Text(StoreStrings.noProducts),
          for (final product in store.products)
            ProductTile(
              product: product,
              onBuy: canUseStore ? () => cubit.buy(product.id) : null,
            ),
          TextButton(
            onPressed: canUseStore ? cubit.restore : null,
            child: const Text(StoreStrings.restore),
          ),
        ],
      ),
    );
  }
}
