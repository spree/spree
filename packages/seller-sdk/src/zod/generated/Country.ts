// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { StateSchema } from './State';

export const CountrySchema = z.object({
  iso: z.string(),
  iso3: z.string(),
  states_required: z.boolean(),
  zipcode_required: z.boolean(),
  states: z.array(StateSchema).optional(),
});

export type Country = z.infer<typeof CountrySchema>;
