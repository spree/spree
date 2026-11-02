# Spree PayPal Checkout

Official [PayPal](https://www.paypal.com) payment gateway for
[Spree Commerce](https://spreecommerce.org), built on Spree's payment session
API.

Supports PayPal, Pay Later, Venmo, and card payments that buyers without a
PayPal account make in PayPal's own window. Honors the store's capture setting:
payments are captured at checkout, or authorized and captured later.

## Installation

```bash
spree add paypal
```

Without the Spree CLI, add `gem 'spree_paypal_checkout'` to the `Gemfile` with
the same version requirement as your `spree` gem and run `bundle install`. The
gateway registers itself — there is nothing to generate and no migrations to
run.

## Configuration

Create a PayPal payment method in the admin dashboard and enter the client id
and secret of your PayPal REST app. Leave Test mode on for sandbox credentials
and turn it off for live ones. Saving queues a job that registers the webhook
with PayPal; until it has run, PayPal's notifications are refused, so if none
arrive, check the job queue for a failed `SpreePaypalCheckout::RegisterWebhookJob`.

Set `PAYPAL_LOG_LEVEL` (for example `debug`) to change how much the PayPal
client logs. Request and response bodies are never logged.

## Upgrading from spree_paypal_checkout 0.x

See the PayPal section of the Spree 5.6 → 6.0 upgrade guide. Two upgrade
steps, `migrate_paypal_payments` and `register_paypal_webhooks`, carry existing
payments and webhooks over; run them before dropping the old
`spree_paypal_checkout_orders` table.

## Testing

The suite runs offline against recorded VCR cassettes:

```bash
bundle exec rake test_app   # once
bundle exec rspec
```

Record cassettes against the PayPal sandbox by adding `RECORD_VCR=1`,
`PAYPAL_CLIENT_ID` and `PAYPAL_CLIENT_SECRET` to the environment and running the
`vcr`-tagged examples.
