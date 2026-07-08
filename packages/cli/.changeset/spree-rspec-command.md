---
"@spree/cli": minor
---

Add `spree rspec` — run the RSpec suite inside the web container without spelling out `spree bundle exec rspec`. Everything after `rspec` is forwarded verbatim (`spree rspec spec/models/spree/brand_spec.rb:15`, `spree rspec --format documentation`), `RAILS_ENV=test` is forced so tests always hit the test database, and when the stack is down the command falls back to a one-off container that cold-starts postgres first.
