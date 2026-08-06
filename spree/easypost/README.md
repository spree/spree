# spree_easypost

Live multi-carrier delivery rates for Spree via [EasyPost](https://www.easypost.com) — the reference implementation of the `Spree::DeliveryRateProvider` interface, built on the official [`easypost`](https://github.com/EasyPost/easypost-ruby) Ruby SDK.

## What it does

- **`SpreeEasyPost::Integration`** holds the store's EasyPost API key (a masked `:password` preference), managed from the dashboard's Settings → Integrations page. The key decides the mode — EasyPost issues separate test and production keys.
- **`SpreeEasyPost::DeliveryRateProvider`** quotes delivery methods live at checkout. Each delivery method maps to one carrier service via method metadata (`carrier` + `service`, e.g. `UPS` / `Ground`); several methods sharing the provider cost a single EasyPost API call per package, and quotes carry the carrier, service level, and estimated delivery date onto the rate.

## Setup

1. Add the gem: `bundle add spree_easypost`
2. In the admin dashboard, open **Settings → Integrations**, connect **EasyPost**, and activate it (activation verifies the key against the EasyPost API).
3. On a delivery method (**Settings → Delivery methods**), pick **EasyPost** as the rate provider and set the method's metadata `carrier` and `service` to the EasyPost identifiers of the service it sells.

Methods without the EasyPost provider keep pricing through their calculator — the two coexist freely per method.

## Notes

- Weights are converted to ounces from the store's unit system (imperial → pounds, metric → grams).
- Label purchase and tracking (a `FulfillmentProvider`) are not part of this gem yet — fulfillment stays manual.
- The gallery card's logo is the official hosted EasyPost asset (`logo_url` — no asset pipeline involved; the dashboard falls back to a letter avatar if unreachable) and its description lives in `config/locales/`, resolved per the store's locale.

## Testing

```bash
cd spree/easypost
bundle install
bundle exec rake test_app
bundle exec rspec
```

Specs stub the EasyPost client — no network calls, no API key needed.

To verify the real API contract (the exact calls the provider makes), run the live smoke check with a test key:

```bash
EASYPOST_TEST_API_KEY=EZTK... bin/smoke
```
