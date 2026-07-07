// This file is auto-generated. Do not edit directly.
// NOTE: hand-authored to match `Spree::Api::V3::StoreSerializer` exactly —
// `pnpm generate:zod` could not run in this sandbox (broken bundler
// executable resolution upstream, unrelated to this change). Run the real
// pipeline (see CLAUDE.md) before merge to confirm/replace this file.
import { z } from 'zod';

export const StoreSchema: z.ZodObject<any> = z.object({
  id: z.string(),
  name: z.string(),
  url: z.string(),
  default_currency: z.string(),
  default_locale: z.string(),
  supported_currencies: z.array(z.string()),
  supported_locales: z.array(z.string()),
  logo_url: z.string().nullable(),
});

export type Store = z.infer<typeof StoreSchema>;
