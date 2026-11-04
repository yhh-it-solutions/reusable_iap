# Troubleshooting

| Symptom | Most likely cause | Fix |
|---|---|---|
| `productsNotFound`, or no products | Store setup | Work through the checklists below |
| iOS: "StoreKit: Failed to get response from platform" | None of the IDs was found | Same checklists |
| `storeUnavailable` on Android | No billing connection, or no Play Store on the device | Use a real device signed in to Google Play |
| `storeUnavailable` on iOS | Purchases restricted (Screen Time, for example) | Check the device's restrictions |
| Android purchase refunded after three days | It was never completed | Check that your `verifyPurchase` returns `true` |
| The same purchase arrives on every launch | The transaction is unfinished | Same check |
| Stuck on pending | A slow payment or a parent's approval | Normal. Grant nothing, and it arrives once paid |
| One subscription was showing several prices | Older versions listed each base plan and offer | Update to 0.1.1, or use one plan per product |
| Your server gets status 21002 from Apple | It sent a StoreKit 2 JWS to `verifyReceipt` | Use the App Store Server Library |
| Works in testing, fails in production | Product not approved yet, or a test-only setup | Check product status, and that the release was submitted with it |

## Products not found: App Store

- [ ] The Paid Apps Agreement is active, under **Business > Agreements**
- [ ] The app's bundle ID matches App Store Connect exactly
- [ ] The In-App Purchase capability is on
- [ ] The product exists with exactly this ID, and its details are filled in
- [ ] You're signed in to a Sandbox Apple Account under **Settings > Developer**
- [ ] You're testing on a real device

## Products not found: Google Play

- [ ] A build is on a track, even just internal testing
- [ ] The product is **active**, along with its purchase option or base plan
- [ ] The application ID matches Play Console exactly
- [ ] The account on the phone is a license tester, and it's the one that installed the app
- [ ] A payments profile is linked to your account
- [ ] If the app was just published to a track, wait: it can take a few hours

Neither store tells your app why an ID is missing, which is why these are checklists. On Google Play, the reason never reaches Dart.

## Read more

- [Flutter In-App Purchase Not Working: Products Not Found](https://bimalkhatri.com.np/blogs/flutter-in-app-purchase-not-working): products in `notFoundIDs`, `isAvailable` false, refunds after three days, purchases replayed on every launch, and pending purchases, in more depth.
