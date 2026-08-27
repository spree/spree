---
"@spree/dashboard-ui": patch
---

Declare the dependencies behind `styles.css` imports: `tailwindcss` as a peer (plus dev) dependency and `shadcn` as a regular dependency. Previously both were undeclared for consumers, so `@import "tailwindcss"` and `@import "shadcn/tailwind.css"` only resolved when pnpm's on-disk layout happened to allow it, failing with `Cannot apply unknown utility class` otherwise.
