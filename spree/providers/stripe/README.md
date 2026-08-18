# Spree Stripe

Official [Stripe](https://stripe.com) payment gateway for
[Spree Commerce](https://spreecommerce.org), built on Spree's payment session
API.

Supports card payments plus Klarna, Affirm, Afterpay, Alipay, iDEAL, Link,
SEPA Direct Debit, Przelewy24 and bank transfers, along with Apple Pay and
Google Pay quick checkout. Customers can save payment methods for later use
through setup sessions.

## Installation

Add the gem to your `Gemfile`:

```ruby
gem 'spree_stripe'
```

Then run `bundle install`. The gateway registers itself — there is nothing to
generate and no migrations to run.

## Configuration

Create a Stripe payment method in the admin dashboard and enter your
publishable and secret keys. Everything else is automatic:

- The webhook endpoint is registered with Stripe on save, and its signing
  secret is stored on the payment method.
- Your storefront domains are registered with Stripe so Apple Pay and Google
  Pay can offer themselves at checkout.

Set `STRIPE_SIGNING_SECRET` to verify webhooks forwarded by the Stripe CLI
during local development.

## Upgrading from spree_stripe 1.x

Signing secrets used to live in their own tables. Move them onto the payment
method with:

```bash
bundle exec rake spree:upgrade:migrate_stripe_webhook_keys
```

This runs as part of `rake spree:upgrade`. Until it does, gateways carrying a
pre-6.0 webhook endpoint will reject incoming webhooks.

Applications still using the Rails storefront checkout, the legacy
`stripe_event` webhook path, or Stripe Tax should complete the payment session
migration before upgrading — those paths ship only in the 1.x series.

## Testing

The suite runs offline against recorded VCR cassettes:

```bash
bundle exec rake test_app   # once
bundle exec rspec
```

Set `RECORD_VCR=1` with real Stripe test credentials to record new
interactions. Note that renaming a `:vcr`-tagged example changes its cassette
path, so it will re-record rather than reuse the old file.
