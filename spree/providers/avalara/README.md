# spree_avalara

Sales tax, VAT and GST for Spree through [Avalara AvaTax](https://www.avalara.com) — the first-party
implementation of the `Spree::TaxProvider` interface, built on Avalara's official
[`avatax`](https://github.com/avadev/AvaTax-REST-V2-Ruby-SDK) SDK.

Avalara prices the whole sale on every call and files a document when the order is placed, so tax is
computed by Avalara rather than from rate tables you maintain.

## Install

```ruby
gem 'spree_avalara'
```

The gem ships no migrations and adds no columns.

## Connect

Settings → Integrations → **Avalara AvaTax**. You need an account number, a license key and the
company code the documents should be filed against. New connections default to Avalara's sandbox
host; switch `endpoint` to `https://rest.avatax.com` when you go live.

| Preference | Meaning |
|---|---|
| `account_number`, `license_key` | Your AvaTax credentials |
| `endpoint` | Sandbox (default) or production host |
| `company_code` | The company documents are filed against |
| `commit_transaction_enabled` | File placed orders as committed (default on). Off files them uncommitted, which is the legacy extension's behaviour |
| `address_validation_enabled` | Refuse a checkout whose US or Canadian address Avalara cannot resolve (default off) |
| `show_rate_in_label` | Reserved; carried over so upgraded settings survive |

Activating the integration verifies the credentials with a ping. A rejected key blocks activation and
shows Avalara's own message.

**Your stock locations need real addresses.** Avalara computes tax from an origin as well as a
destination, so a warehouse carrying only a country makes every estimate fail. Fill in street, city,
region and postal code for the locations you ship from.

**A market pointing at a disconnected integration computes no tax.** Deactivating the integration
does not break your storefront — carts and checkout keep working, Avalara simply has no opinion, and
the misconfiguration is reported to your error tracker. Watch for orders with no tax after a
credential change. A *connected* Avalara that cannot be reached does fail closed, because that is
the case where quietly charging nothing is a liability rather than a setting.

## Calculate through Avalara

Tax engines are chosen per market: set a market's tax provider to **Avalara AvaTax** and every sale in
it calculates through your account. Markets you leave alone keep using Spree's built-in engine, so you
can move one region at a time.

## How exemptions reach Avalara

Company tax exemption certificates recorded in Spree are translated into Avalara entity use codes and
sent with the sale. A reason Avalara does not define is sent as OTHER/CUSTOM, and the reason you
recorded is kept on the tax row.

## Upgrading from `spree_avatax_official`

```bash
bin/rails spree_avalara:upgrade
```

Idempotent, and not needed on a fresh install. It retypes your existing integration (credentials carry
over untouched), turns legacy `spree_users.vat_id` values into buyer tax registrations, deletes the
synthesized "AvaTax Official Tax Rate" rows — left behind, Spree's own engine would read them as real
configuration — and points markets that name no engine at Avalara. A market where you chose an engine
explicitly, including Spree's own, is never rewritten.

A legacy `vat_id` that no longer validates is reported rather than migrated, so you can reconcile the
list; until then that buyer is charged as a consumer, which is the safe direction.

Legacy schema is left in place. When you are satisfied with the result:

```bash
bin/rails spree_avalara:upgrade:drop_legacy_schema
```

That keeps `spree_users.exemption_number` and `avatax_entity_use_code_id`, which are the source for
whichever answer individual exemptions get.

**Orders filed by the legacy extension carry no Avalara document id.** The legacy table recorded the
document *code*, which is the order number — and that is what voids and credits key on anyway, so
nothing is lost.

## Development

```bash
cd spree/providers/avalara
bundle install
bundle exec rake test_app   # once, to generate spec/dummy
bundle exec rspec
```

The suite makes no network calls. Specs that assert what Avalara actually returns are backed by VCR
cassettes recorded by the maintainer against a sandbox account, and skip themselves while their
cassette is absent. To record:

```bash
AVATAX_ACCOUNT_NUMBER=… AVATAX_LICENSE_KEY=… AVATAX_COMPANY_CODE=… VCR_RECORD_MODE=new_episodes bundle exec rspec spec/integration
```

Credentials and the account's own user name are filtered out of every cassette.
