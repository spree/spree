# spree_vies

Checks whether a customer's EU VAT number is really registered, by asking [VIES](https://ec.europa.eu/taxation_customs/vies/) — the European Commission's VAT Information Exchange System. VIES is free and needs no account, so there is nothing to configure.

## What it does

Spree already checks that an EU VAT number is well-formed. That catches typos, but it cannot tell you whether the business exists. This gem adds that second check.

- **Verified or not.** Each number is asked about in the background whenever it is added or changed. A number VIES reports as registered is marked `verified`; one it reports as not registered is marked `unverified`. A malformed number is marked `unverified` without asking.
- **Evidence.** Every answer is stored with the number: the name and address VIES holds for the business, when it was asked, and the last ten answers. VIES only ever says whether a number is registered *now*, so this record is the only proof that a number was valid on the day an order was zero-rated.
- **Outages are not rejections.** VIES relays each question to the member state's own registry, and those go offline often. A number nobody could answer is marked `unavailable` — never `unverified` — and asked about again with a growing delay, for up to a day. When VIES asks for fewer requests at once, every check waits ten minutes. If a number already had an answer, an outage leaves that answer in place.
- **Answers expire.** Businesses get deregistered. `spree_vies:revalidate` asks again about every number whose last answer is older than 90 days, and about numbers that were never asked (for example, ones entered before the gem was installed).

The gem records verdicts; it does not block checkout. What a verdict means for tax — whether an `unavailable` number still gets reverse charge, for example — is for the tax provider to decide.

## Setup

1. Add the gem: `bundle add spree_vies`
2. Run the re-check once a day. With Solid Queue, in `config/recurring.yml`:

   ```yaml
   production:
     revalidate_eu_vat_numbers:
       class: SpreeVies::RevalidateJob
       schedule: every day at 3am
   ```

   Or from any scheduler: `bin/rails spree_vies:revalidate`

To trust answers for a different period, set it in `config/initializers/spree.rb`:

```ruby
SpreeVies.freshness = 30.days
```

Retries, the rate-limit pause and the guard against checking one number twice at once use `Rails.cache`. With more than one server or worker process, use a cache store they share (Solid Cache, Redis or Memcached).

## Testing

```bash
cd spree/providers/vies
bundle install
bundle exec rake test_app
bundle exec rspec
```

The specs never call VIES. They replay responses captured from it, stored in `spec/fixtures/files/vies/`.
