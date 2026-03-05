// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { StoreMarketSchema } from './StoreMarket';
import { StoreStateSchema } from './StoreState';

export const StoreCountrySchema: z.ZodObject<any> = z.object({
  iso: z.string(),
  iso3: z.string(),
  name: z.string(),
  states_required: z.boolean(),
  zipcode_required: z.boolean(),
  states: z.array(StoreStateSchema).optional(),
  market: z.lazy(() => StoreMarketSchema).nullable().optional(),
});

export type StoreCountry = z.infer<typeof StoreCountrySchema>;
