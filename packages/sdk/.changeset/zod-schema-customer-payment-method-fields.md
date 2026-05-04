---
'@spree/sdk': minor
---

Sync Zod schemas with TypeScript types for `Customer` and `PaymentMethod`.

- `CustomerSchema` now includes `full_name: string` (already present in the `Customer` type since the Admin Customers API landed; the runtime schema was stale).
- `PaymentMethodSchema` now includes `source_required: boolean` (already present in the `PaymentMethod` type).

No source-API change — this only affects callers using `CustomerSchema` / `PaymentMethodSchema` for runtime validation (e.g., `CustomerSchema.parse(response)`). Validation no longer rejects these fields and parsed values are correctly typed.
