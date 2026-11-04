import 'package:flutter/material.dart';

import '../store_strings.dart';

class AccessCard extends StatelessWidget {
  const AccessCard({super.key, required this.isPremium, required this.coins});

  final bool isPremium;
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(isPremium ? Icons.verified : Icons.lock_outline),
        title: Text(isPremium ? StoreStrings.premium : StoreStrings.notPremium),
        subtitle: Text(StoreStrings.coins(coins)),
      ),
    );
  }
}
