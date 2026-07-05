# Render deployment

This repository is a Spree backend source repository. The Render blueprint creates a deployable Spree app in `./server` from `spree/spree-starter` during the build, then runs that app with the Spree sources from this repository through `SPREE_PATH=..`.

## Deploy

1. In Render, choose **New → Blueprint**.
2. Select this repository and the `render-deploy-setup` branch first.
3. Render will create:
   - `kakaowy-sklepik-backend` Ruby web service,
   - `kakaowy-sklepik-db` PostgreSQL database,
   - `kakaowy-sklepik-redis` Redis instance.
4. After the backend deploys, open the backend service URL and verify `/up` returns OK.
5. Use the backend URL as `SPREE_API_URL` in `KakaowySklepikFront`.

## Important

The current blueprint intentionally keeps the Sidekiq worker commented out because Render workers require a paid plan. Enable it in `render.yaml` when background jobs become necessary.

The frontend still uses Shopify for some legacy template paths, so keep the Shopify environment variables set there until those paths are migrated to Spree.
