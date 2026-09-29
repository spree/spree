// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { CountrySchema } from './Country';

export const MarketSchema: z.ZodObject<any> = z.object({
  id: z.string(),
  name: z.string(),
  currency: z.string(),
  default_locale: z.string(),
  tax_inclusive: z.boolean(),
  default: z.boolean(),
  country_codes: z.array(z.string()),
  country_isos: z.array(z.string()),
  supported_locales: z.array(z.string()),
  countries: z.array(z.lazy(() => CountrySchema)).optional(),
  tax_provider: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});

export type Market = z.infer<typeof MarketSchema>;
