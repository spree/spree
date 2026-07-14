# spree_dashboard

Hosts the [Spree React Dashboard](https://spreecommerce.org/docs/developer/dashboard/overview) from your Spree server — the **single-node topology**: the dashboard and the Admin API share one origin, so there are no CORS entries to maintain and auth cookies stay `SameSite=Lax`.

> **Developer Preview.** In Spree 6 this gem becomes the default admin delivery. The path is permanent: the dashboard lives at `/dashboard`, and `/admin` stays reserved for the classic `spree_admin`.

## What it does

Serves a built dashboard (`vite build` output) at **`/dashboard`** with SPA semantics: every dashboard route falls back to `index.html` (no-cache), Vite's content-hashed `assets/` get immutable caching, and paths are traversal-guarded. The bundle is public client code, so there's no authentication on the route — the SPA authenticates its API calls itself.

## Setup

```ruby
# Gemfile
gem 'spree_dashboard'
```

Point it at a built dashboard, either via env (what the official Docker image and the Render Blueprint use):

```bash
SPREE_DASHBOARD_DIST_PATH=/rails/dashboard
```

or an initializer:

```ruby
# config/initializers/spree.rb
Spree::Dashboard.dist_path = Rails.root.join('dashboard/dist').to_s
```

Unset, `/dashboard` responds 404.

The bundle must be built for sub-path mounting with a relative API base: `VITE_BASE_PATH=/dashboard/ pnpm build` (and `VITE_SPREE_API_URL` unset) — see the [deployment docs](https://spreecommerce.org/docs/developer/dashboard/deployment) for the full picture, including baking it into a Docker image.

## Testing

```bash
bundle install
bundle exec rake test_app   # generates the dummy app (skip if present)
bundle exec rspec
```
