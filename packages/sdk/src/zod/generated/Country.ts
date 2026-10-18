// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type Country from '../../types/generated/Country';
import { MarketSchema } from './Market';
import { StateSchema } from './State';

export const CountrySchema = z.object({
  iso: z.string(),
  iso3: z.string(),
  name: z.string(),
  states_required: z.boolean(),
  zipcode_required: z.boolean(),
  states: z.array(StateSchema).optional(),
  get market() { return MarketSchema.nullable().optional(); },
}) as unknown as z.ZodType<Country>;

export type { Country };
