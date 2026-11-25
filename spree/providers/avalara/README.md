# Spree Avalara

The officially supported Avalara AvaTax extension for [Spree Commerce](https://spreecommerce.org/)
using [Avalara REST API v2](https://developer.avalara.com/api-reference/avatax/rest/v2/).

`spree_avalara` is the Spree 6 successor of the `spree_avatax_official` extension. It implements
Spree's `Spree::TaxProvider` interface on Avalara's official
[`avatax`](https://github.com/avadev/AvaTax-REST-V2-Ruby-SDK) SDK. For Spree 5 use
[spree_avatax_official](https://github.com/spree/spree_avatax_official).

- [Introduction](#introduction)
- [Maintenance & support](#maintenance--support)
- [Features](#features)
- [Installation](#installation)
- [Setup](#setup)
- [Upgrading from `spree_avatax_official`](#upgrading-from-spree_avatax_official)
- [Development](#development)
- [Contributing](#contributing)

## Introduction

Avalara AvaTax is a cloud-based solution automating transaction tax calculations and the tax filing
process. Avalara provides real-time tax calculation using tax content from more than 12,000 US taxing
jurisdictions and over 200 countries, ensuring your transaction tax is calculated based on the most
current tax rules.

Avalara prices the whole sale on every call and files a document when the order is placed, so tax is
computed by Avalara rather than from rate tables you maintain.

## Maintenance & support

This extension is maintained by the Spree Commerce core team and Avalara, and will be kept up to date
with future Avalara platform changes.

For more information, support and guidance on how to implement the Spree Avalara extension feel free to:

- Read the [Spree Avalara AvaTax documentation](https://spreecommerce.org/docs/integrations/tax/avalara)
- Reach out through the [Spree contact form](https://spreecommerce.org/contact/)
- Join the Spree Discord at [discord.spreecommerce.org](https://discord.spreecommerce.org/)

## Features

1. Tax calculation (additional and included tax) — US state tax, Canadian HST and VAT supported
2. Tax calculation on line items, shipping charges and fees
3. Tax codes for products and shipping, assignable per tax category and searchable from Avalara's catalogue
4. Multi-stock location support — origin-based tax calculation per shipment across your fulfilment network
5. Tax exemptions — entity use codes on company exemption certificates, and buyer tax registrations (VAT numbers)
6. Address validation for US and Canada at checkout
7. Committing complete orders as sales invoice transactions
8. Cancelling (voiding) orders
9. Refunding orders (full and partial) — returns, claims and exchanges file a credit with the tax the sale charged
10. Per-market setup — move one region at a time while the others keep Spree's built-in tax engine
11. Client-side logging

## Installation

```bash
spree add avatax
```

Without the Spree CLI, add `gem 'spree_avalara'` to the `Gemfile` with the same version
requirement as your `spree` gem and run `bundle install`. The provider registers itself — there is
nothing to generate, and the gem ships no migrations and adds no columns.

## Setup

### Connect Spree to AvaTax

In the admin dashboard open **Settings → Integrations**, find the **Avalara AvaTax** tile and connect
it. You need an account number, a license key and the company code the documents should be filed
against. New connections default to Avalara's sandbox
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

### Calculate through Avalara

Tax engines are chosen per market: set a market's tax provider to **Avalara AvaTax** and every sale in
it calculates through your account. Markets you leave alone keep using Spree's built-in engine, so you
can move one region at a time.

### How exemptions reach Avalara

Company tax exemption certificates recorded in Spree are sent with the sale, each with the code of its
exemption reason. Exemption reasons are your store's own list, managed under **Settings → Taxes → Exemption reasons**:
give each one an Avalara entity use code (`G` for resale, `A` for federal government, …) and name it
however you like. A new store's six default reasons carry neutral codes, so change the ones you use to
Avalara's; once a market uses Avalara the dashboard offers Avalara's codes, and every certificate follows the change.

A reason whose code Avalara does not define is sent as OTHER/CUSTOM, and the reason you recorded is kept
on the tax row.

### Returns, claims and exchanges

The tax given back on a return, a claim or an exchange is exactly what the sale charged on the units
coming back, so a customer is never refunded more or less tax than they paid. Once the money has gone
back, Spree files a credit with Avalara carrying that same tax. The credit is dated the day of the
refund but taxed as of the original sale, and it is keyed to the return, claim or exchange number, so
retrying a refund adjusts one document.

An exchange's replacement is taxed by Avalara as a new sale while the exchange is open, and filed as
its own document once it ships.

## Upgrading from `spree_avatax_official`

Replace `spree_avatax_official` with `spree_avalara` in your `Gemfile`, using the same version
requirement as your `spree` gem. The old extension's install generator and migrations are gone. Then run:

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

Legacy schema is left in place. Dropping it removes `spree_users.vat_id`, the only copy of a reported
value, so reconcile or export those first. When you are satisfied with the result:

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
cassettes recorded by the maintainer against a sandbox account; a missing cassette fails its spec.
To record:

```bash
AVATAX_ACCOUNT_NUMBER=… AVATAX_LICENSE_KEY=… AVATAX_COMPANY_CODE=… VCR_RECORD_MODE=new_episodes bundle exec rspec spec/integration
```

Credentials and the account's own user name are filtered out of every cassette.

## Contributing

This gem lives in the [Spree monorepo](https://github.com/spree/spree) under `spree/providers/avalara`.
Please open issues and pull requests there.

Copyright (c) 2026-present [Vendo Sp. z o.o.](https://getvendo.com), [Vendo Connect Inc.](https://getvendo.com), released under the [MIT license](LICENSE).
