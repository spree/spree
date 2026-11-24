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
| `document_recording` | What happens to a placed sale at Avalara. **Record and commit** (default) files it as Committed. **Record without committing** files it as Saved, so it stays out of Avalara's filings until something commits it — the legacy extension's behaviour with commit switched off. **Don't record** files nothing: only quotes are sent, and no sale, void or credit reaches Avalara, for a store whose ERP records the sales instead. The tax charged is the same in all three. Switching to Don't record also stops voids and credits for documents recorded before the switch |
| `address_validation_enabled` | Refuse a checkout whose US or Canadian address Avalara cannot resolve (default off) |
| `show_rate_in_label` | Reserved; carried over so upgraded settings survive |
| `logging_enabled` | Write every AvaTax call to the Rails log (default off) — see below |

Activating the integration verifies the credentials with a ping. A rejected key blocks activation and
shows Avalara's own message.

**Logging.** With `logging_enabled` on, every call to Avalara writes one line to your Rails log, tagged
`[AVATAX]`: the operation, the HTTP status (or the network error), how long it took, and the request and
response bodies. Credentials are never logged. The bodies carry customer addresses, and a guest's email
is their customer code, so switch it on while you need it and keep the log under your usual retention.

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

Company tax exemption certificates recorded in Spree are sent with the sale, each with the code of its
exemption reason. Exemption reasons are your store's own list, managed under **Settings → Taxes → Exemption reasons**:
give each one an Avalara entity use code (`G` for resale, `A` for federal government, …) and name it
however you like. A new store's six default reasons carry neutral codes, so change the ones you use to
Avalara's; once a market uses Avalara the dashboard offers Avalara's codes, and every certificate follows the change.

A reason whose code Avalara does not define is sent as OTHER/CUSTOM, and the reason you recorded is kept
on the tax row.

## Returns, claims and exchanges

The tax given back on a return, a claim or an exchange is exactly what the sale charged on the units
coming back, so a customer is never refunded more or less tax than they paid. Once the money has gone
back, Spree files a credit with Avalara carrying that same tax. The credit is dated the day of the
refund but taxed as of the original sale, and it is keyed to the return, claim or exchange number, so
retrying a refund adjusts one document.

An exchange's replacement is taxed by Avalara as a new sale while the exchange is open, and filed as
its own document once it ships.

## Upgrading from `spree_avatax_official`

```bash
bin/rails spree_avalara:upgrade
```

Idempotent, and not needed on a fresh install. It retypes your existing integration (credentials carry
over untouched, and a legacy "commit transactions" switch that was off becomes **Record without committing**), turns legacy `spree_users.vat_id` values into buyer tax registrations, deletes the
synthesized "AvaTax Official Tax Rate" rows — left behind, Spree's own engine would read them as real
configuration — points markets that name no engine at Avalara, and gives each connected store an
exemption reason per Avalara entity use code, as the legacy extension's code table did. A market where
you chose an engine explicitly, including Spree's own, is never rewritten.

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
