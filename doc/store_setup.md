# Store setup

Do this before you debug any code: most "products not found" problems are a missing step here. Menu names were checked in September 2026, and the consoles do change them.

## What you need first

| | Apple | Google |
|---|---|---|
| **Account** | Apple Developer Program membership | Google Play developer account |
| **App** | An app in App Store Connect | An app in Play Console |
| **ID** | A [bundle ID](https://bimalkhatri.com.np/blogs/bundle-id-vs-app-id) matching your Xcode project | An application ID matching `build.gradle` |

## App Store

**1. Sign the paperwork.** In App Store Connect, under **Business > Agreements**, the Account Holder signs the Paid Apps Agreement. Then add tax forms and a bank account in the same place. You can't create a purchase until the agreement is signed.

**2. Add the capability.** In Xcode, open the Runner target, then **Signing & Capabilities > + Capability > In-App Purchase**. New to signing? See [Flutter iOS code signing](https://bimalkhatri.com.np/blogs/flutter-ios-code-signing).

**3. Create the products.** Open your app, then under **Monetization**:

- **In-App Purchases** for consumables and non-consumables.
- **Subscriptions** for subscriptions, inside a subscription group. A user holds one plan per group.

Fill in the reference name, price and localization. The product ID locks once saved and can never be reused in that app.

**4. Plan the first review.** The first item of each type must be submitted with a new app version.

**5. Create testers.** Under **Users and Access > Sandbox**, add a Sandbox Apple Account. On the iPhone, sign in at **Settings > Developer > Sandbox Apple Account**, which appears after you first try a purchase in a development build.

## Google Play

**1. Set up payments.** In **Settings > Payments profile**, create a payments profile. It links to Play Console automatically.

**2. Upload a build.** Google enables billing screens only after a build with the billing library is on a track. Upload a [signed](https://bimalkhatri.com.np/blogs/flutter-release-signing) app bundle to **Test and release > Testing > Internal testing**. The `BILLING` permission comes with the plugin, so you don't add it.

**3. Create the products.** Under **Monetize with Play > Products**:

- **One-time products** for consumables and non-consumables: add a Buy purchase option, then activate it.
- **Subscriptions**: add a base plan, then activate it.

Nothing loads until it's active. If you can, use one base plan per subscription: this package uses the first plan the store returns for an ID, so sell two plans as two products.

**4. Add testers.** In **Settings > License testing**, add your testers' emails. They can then buy with test cards and run debug builds with `flutter run`, as long as the package name matches. Your own account always counts.

**5. Check the phone.** On a device with several accounts, the purchase uses the account that downloaded the app. Make that the tester.

## Before release

- **Use the same product IDs on both stores**, so your Dart code never branches by platform.
- **Show what Apple requires on a subscription screen:** the plan's name, length and price, what the user gets, and links to your terms of use and privacy policy.
- **Add a Restore Purchases button.** Apple expects one, and `iap.restore()` is all it takes.
- **Test on a real device.** Rely on sandbox and test cards, not the simulator.
- **New personal Google accounts** must run a closed test with at least 12 testers for 14 days before production.

Stuck? See [troubleshooting](troubleshooting.md).
