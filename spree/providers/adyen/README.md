# Spree Adyen

Adyen payments for [Spree Commerce](https://spreecommerce.org): cards, wallets
and local payment methods through Adyen's Sessions flow and Drop-in, on the
Spree payment session API.

Add the gem to your Spree application:

```ruby
gem 'spree_adyen'
```

The gateway registers itself. Add an Adyen payment method in the admin and
enter your API key, merchant account and, for live, the live URL prefix.

See the [Adyen guide](https://spreecommerce.org/docs/integrations/payments/adyen)
for setup and the storefront.
