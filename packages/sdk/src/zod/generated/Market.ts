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
  supported_locales: z.array(z.string()),
  countries: z.array(z.lazy(() => CountrySchema)).optional(),
});

export type Market = z.infer<typeof MarketSchema>;
