## 0.1.2

- Fix a new `state` listener missing updates that came just after it joined, which could leave it stuck on `loading`
- Rebuild the example as a small store in clean architecture, with tests that need no store
- Add a clean architecture guide, and links to in-depth articles from the README and guides
- Add the MIT license
- Add an install guide
- Draw the README's diagram as an image, in light and dark, and keep it and the badges in the repo, so the README relies on no outside service

## 0.1.1

- Allow `equatable` 3
- Offer one product per ID on Google Play, which returns an entry for each base plan and offer of a subscription. The price shown is now the plan that gets bought
- Report a purchase the store refuses to start, instead of staying in `loading` with nothing on the purchase stream
- Complete failed and cancelled purchases that the store marks as pending completion, as the `in_app_purchase` docs do
- Report errors from `isAvailable` and `queryProducts` through state, instead of throwing and staying in `loading`
- Keep loaded products when a refresh fails
- Check the store again while it is unavailable, so a later `loadProducts`, `buy` or `restore` recovers
- Share one store check between overlapping `initialize` calls
- Rewrite the README and add guides in `doc/`

## 0.1.0

- Renamed the package to `reusable_iap`
- Rebuilt the package as a headless IAP service on top of `in_app_purchase`
- Added normalized public models for products, purchases, errors, and state
- Added support for consumables, non-consumables, and subscriptions
- Added a `BillingGateway` abstraction for testability
- Added restore handling, entitlement resolution, and pluggable purchase verification
- Added internal purchase acknowledgement logic
- Added a publish-ready README, example app, and publishing checklist
