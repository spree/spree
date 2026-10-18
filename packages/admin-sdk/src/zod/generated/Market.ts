// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type Market from '../../types/generated/Market';
import { CountrySchema } from './Country';

export const MarketSchema = z.object({
  id: z.string(),
  name: z.string(),
  currency: z.string(),
  default_locale: z.string(),
  tax_inclusive: z.boolean(),
  default: z.boolean(),
  country_codes: z.array(z.string()),
  supported_locales: z.array(z.string()),
  get countries() { return z.array(CountrySchema).optional(); },
  created_at: z.string(),
  updated_at: z.string(),
  tax_provider: z.string().nullable(),
}) as unknown as z.ZodObject<{
  id: z.ZodType<Market['id']>;
  name: z.ZodType<Market['name']>;
  currency: z.ZodType<Market['currency']>;
  default_locale: z.ZodType<Market['default_locale']>;
  tax_inclusive: z.ZodType<Market['tax_inclusive']>;
  default: z.ZodType<Market['default']>;
  country_codes: z.ZodType<Market['country_codes']>;
  supported_locales: z.ZodType<Market['supported_locales']>;
  countries: z.ZodOptional<z.ZodType<Exclude<Market['countries'], undefined>>>;
  created_at: z.ZodType<Market['created_at']>;
  updated_at: z.ZodType<Market['updated_at']>;
  tax_provider: z.ZodType<Market['tax_provider']>;
}>;

export type { Market };
