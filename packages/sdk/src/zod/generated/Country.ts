// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { MarketSchema } from './Market';
import { StateSchema } from './State';

export const CountrySchema: z.ZodObject<any> = z.object({
  iso: z.string(),
  iso3: z.string(),
  name: z.string(),
  states_required: z.boolean(),
  zipcode_required: z.boolean(),
  states: z.array(StateSchema).optional(),
  market: z.lazy(() => MarketSchema).nullable().optional(),
});

export type Country = z.infer<typeof CountrySchema>;
