import 'package:shared_preferences/shared_preferences.dart';

/// What must survive a restart. The package keeps access in memory only.
class StoreCache {
  const StoreCache(this._prefs);

  static const _isPremiumKey = 'store.is_premium';
  static const _coinsKey = 'store.coins';

  final SharedPreferences _prefs;

  bool get isPremium => _prefs.getBool(_isPremiumKey) ?? false;

  int get coins => _prefs.getInt(_coinsKey) ?? 0;

  Future<void> saveIsPremium(bool value) =>
      _prefs.setBool(_isPremiumKey, value);

  Future<void> saveCoins(int value) => _prefs.setInt(_coinsKey, value);
}
