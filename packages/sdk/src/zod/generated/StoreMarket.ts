// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { StoreCountrySchema } from './StoreCountry';

export const StoreMarketSchema = z.object({
  id: z.string(),
  name: z.string(),
  currency: z.string(),
  default_locale: z.string(),
  tax_inclusive: z.boolean(),
  default: z.boolean(),
  supported_locales: z.array(z.string()),
  countries: z.array(StoreCountrySchema),
});

export type StoreMarket = z.infer<typeof StoreMarketSchema>;
