# Render deployment

This repository currently uses `bin/render-build.sh` to create a temporary deployable Spree app in `./server` from `spree/spree-starter` during the Render build.

The current Render setup is intentionally optimized for a **build-only smoke test** first. It verifies that the backend can be cloned, bundled and asset-compiled on Render without connecting external services yet.

## Current confirmed status

A Render Web Service build has passed successfully with **no application environment variables configured**.

The successful test used:

```sh
Build Command: bash bin/render-build.sh
Start Command: cd server && bundle exec puma -C config/puma.rb
Root Directory: <empty>
Health Check Path: /up
```

During this build, `DATABASE_URL` was intentionally not set, so the script skipped database preparation:

```text
→ Skipping database preparation because DATABASE_URL is not set
==> Build successful 🎉
```

This is expected for the current test stage. It means the app builds, but it does **not** mean the backend is ready to run as a real store yet.

## How the build script works

`bin/render-build.sh` currently:

1. Clones `spree/spree-starter` into `./server`.
2. Forces the generated app to use Ruby `3.4.4`, matching the Render runtime used by this service.
3. Removes `server/.env` so the starter uses published Spree gems instead of local `SPREE_PATH` path gems.
4. Sets `SECRET_KEY_BASE_DUMMY=1` so Rails can run `assets:precompile` without a production secret during a build-only test.
5. Runs `bundle install`.
6. Runs `bundle exec rails assets:precompile`.
7. Runs `bundle exec rails db:prepare` only when `DATABASE_URL` exists.

## Build-only test setup

For a build-only Render test, no app env vars are required.

Use:

```sh
Build Command: bash bin/render-build.sh
Start Command: cd server && bundle exec puma -C config/puma.rb
```

Leave `Root Directory` empty.

The app may still fail to fully start after a successful build if no database is attached. That is acceptable for this stage because the goal is only to prove that the backend can build on Render.

## Production/runtime setup later

To run the backend as a real Spree store, add the required services and environment variables:

```sh
DATABASE_URL=<Render Postgres internal database URL>
SECRET_KEY_BASE=<long random secret>
RAILS_ENV=production
RACK_ENV=production
RAILS_SERVE_STATIC_FILES=true
```

Optional but recommended later:

```sh
REDIS_URL=<Render Redis/internal key value URL>
JWT_SECRET_KEY=<long random secret for Spree API JWTs>
```

After `DATABASE_URL` is set, `bin/render-build.sh` will automatically run:

```sh
bundle exec rails db:prepare
```

## Important notes

The current build intentionally avoids `SPREE_PATH=..` on Render. Earlier attempts to deploy with local path gems required rewriting `Gemfile.lock` during the build and were fragile in Render's Ruby environment. The current stable build uses the published Spree gems from `spree-starter` instead.

The Sidekiq worker remains commented out in `render.yaml` because Render workers require a paid plan. Enable it only when background jobs become necessary.

The frontend still uses Shopify for some legacy template paths, so keep the Shopify environment variables set there until those paths are migrated to Spree.
