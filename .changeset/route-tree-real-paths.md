---
"@spree/dashboard-core": patch
"@spree/dashboard": patch
"@spree/seller-dashboard": patch
---

Fixed type checking in projects that install the dashboard or seller panel with pnpm. The generated route file imported the routes through the package's `node_modules` link, where TypeScript cannot find the dashboard's own dependencies, so `tsc` reported hundreds of "Cannot find module" errors. It now imports them from the installed location again. Under pnpm that location includes the package version, so an upgrade rewrites the import paths in `routeTree.gen.ts`.
