import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'modules/store/domain/repository/store_repository.dart';
import 'modules/store/domain/use_case/buy_product_use_case.dart';
import 'modules/store/domain/use_case/restore_purchases_use_case.dart';
import 'modules/store/domain/use_case/start_store_use_case.dart';
import 'modules/store/domain/use_case/watch_store_use_case.dart';
import 'modules/store/presentation/cubit/store_cubit.dart';
import 'modules/store/presentation/views/paywall_screen.dart';

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key, required this.repository});

  final StoreRepository repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // Above MaterialApp and not lazy: a purchase can land at any moment, so
      // the store has to be listening before any paywall opens.
      lazy: false,
      create: (_) => StoreCubit(
        watchStore: WatchStoreUseCase(repository),
        startStore: StartStoreUseCase(repository),
        buyProduct: BuyProductUseCase(repository),
        restorePurchases: RestorePurchasesUseCase(repository),
      )..load(),
      child: MaterialApp(
        title: 'Reusable IAP Example',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        ),
        home: const PaywallScreen(),
      ),
    );
  }
}
