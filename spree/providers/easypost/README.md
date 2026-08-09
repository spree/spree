# spree_easypost

Live multi-carrier delivery rates for Spree via [EasyPost](https://www.easypost.com) — the reference implementation of the `Spree::DeliveryRateProvider` interface, built on the official [`easypost`](https://github.com/EasyPost/easypost-ruby) Ruby SDK.

## What it does

- **`SpreeEasyPost::Integration`** holds the store's EasyPost API key (a masked `:password` preference), managed from the dashboard's Settings → Integrations page. The key decides the mode — EasyPost issues separate test and production keys.
- **`SpreeEasyPost::DeliveryRateProvider`** quotes live at checkout. One delivery method is the carrier connection: every service EasyPost returns for the address becomes its own named rate ("UPS Ground", "USPS Priority Mail", …) carrying the carrier, service level and estimated delivery date. The method's service rows optionally narrow which services are offered, rename them, or add a markup per service; with no rows, everything EasyPost returns is offered and the method-level markup applies. One EasyPost API call per package, however many services come back.
- **`SpreeEasyPost::FulfillmentProvider`** buys the label when a fulfillment ships — the rate quoted at checkout when still valid, otherwise a fresh quote bought only for the exact carrier service the customer selected. Tracking lands on the fulfillment, the label is served via `documents`, and cancelling files a refund request. A purchase failure never blocks shipping — it is reported and the admin buys the label manually.

## Setup

1. Add the gem: `bundle add spree_easypost`
2. In the admin dashboard, open **Settings → Integrations**, connect **EasyPost**, and activate it (activation verifies the key against the EasyPost API).
3. Create ONE delivery method (**Settings → Delivery methods**) with **EasyPost** as its rate and fulfillment provider. The service picker lists what your EasyPost account can actually quote — read from a throwaway quote rather than the carrier-accounts endpoint, which is production-only and reports no service levels. That's enough — customers see every service EasyPost quotes. Optionally narrow the offered services, rename them ("UPS 1 day"), or add a handling-fee markup, per service or method-wide.

Methods without the EasyPost provider keep pricing through their calculator — the two coexist freely per store.

## Notes

- Weights are converted to ounces from the store's unit system (imperial → pounds, metric → grams).
- The gallery card's logo is the official hosted EasyPost asset (`logo_url` — no asset pipeline involved; the dashboard falls back to a letter avatar if unreachable) and its description lives in `config/locales/`, resolved per the store's locale.

## Testing

```bash
cd spree/providers/easypost
bundle install
bundle exec rake test_app
bundle exec rspec
```

The suite runs offline: unit specs stub the client, and the API-contract specs replay recorded HTTP through VCR (`spec/vcr/`). To re-record the cassettes against the live EasyPost test API, delete them and run the suite with `EASYPOST_TEST_API_KEY` set — the key is filtered out of recordings.

For a quick live sanity check outside the suite:

```bash
EASYPOST_TEST_API_KEY=EZTK... bin/smoke
```
