# spree_avalara

Sales tax, VAT and GST for Spree via [Avalara AvaTax](https://www.avalara.com) — the reference
implementation of the `Spree::TaxProvider` interface, built on Avalara's official
[`avatax`](https://github.com/avadev/AvaTax-REST-V2-Ruby-SDK) Ruby SDK. Credentials are stored per
store as a `SpreeAvalara::Integration`, and a market calculates through Avalara by naming
`SpreeAvalara::TaxProvider` as its tax provider.

Installation, configuration and the upgrade path from `spree_avatax_official` are documented as this
gem is built out; see `docs/plans/6.0-avalara-provider-gem.md` in the monorepo for the design.

## Development

```bash
cd spree/providers/avalara
bundle install
bundle exec rake test_app   # once, to generate spec/dummy
bundle exec rspec
```

The suite makes no network calls. Specs that assert what Avalara actually returns are backed by VCR
cassettes recorded by the maintainer against an AvaTax sandbox account, and skip themselves while
their cassette is absent.
