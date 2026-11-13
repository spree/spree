# Spree Klaviyo

Official [Klaviyo](https://www.klaviyo.com) marketing integration for
[Spree Commerce](https://spreecommerce.org).

Sends Klaviyo your customer profiles, newsletter sign-ups and the order
lifecycle under Klaviyo's standard metric names (Placed Order, Ordered
Product, Fulfilled Order, Canceled Order), plus Return Refunded. Klaviyo runs
the newsletter confirmation, and can take over the order emails at your
choice. Erasing a customer in Spree deletes their Klaviyo profile.

## Installation

```bash
spree add klaviyo
```

Without the Spree CLI, add `gem 'spree_klaviyo'` to the `Gemfile` with the
same version requirement as your `spree` gem and run `bundle install`. The
integration registers itself — there is nothing to generate and no migrations
to run.

The Klaviyo SDK uses libcurl.

## Configuration

Open Settings → Integrations in the admin dashboard, add Klaviyo, and enter a
private API key and the id of the list newsletter sign-ups go to. See the
[Klaviyo guide](https://spreecommerce.org/docs/integrations/marketing/klaviyo)
for the key's scopes, the list's opt-in setting and the email switches.

## Testing

From the repository root:

```bash
pnpm test:rspec klaviyo
```

Specs replay recorded Klaviyo responses from `spec/vcr`. To record new ones
against a Klaviyo test account, set `RECORD_VCR=1` and
`KLAVIYO_PRIVATE_API_KEY`; the key and the `Authorization` header are
redacted from the cassettes.
