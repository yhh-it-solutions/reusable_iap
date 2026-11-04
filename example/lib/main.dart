import 'package:flutter/material.dart';
import 'package:reusable_iap/reusable_iap.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'modules/store/data/repository/store_repository_impl.dart';
import 'modules/store/data/store_cache.dart';
import 'modules/store/data/store_catalog.dart';

/// Everything is built once, here. It's the one place outside `data/` that
/// knows `reusable_iap` exists.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final repository = StoreRepositoryImpl(
    iap: IapService(
      config: StoreCatalog.config,
      entitlementResolver: StoreCatalog.entitlementsFor,
      // With a backend, add: verifyPurchase: myApi.verify,
    ),
    cache: StoreCache(await SharedPreferences.getInstance()),
  );

  runApp(ExampleApp(repository: repository));
}
