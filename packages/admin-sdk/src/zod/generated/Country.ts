// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type Country from '../../types/generated/Country';
import { MarketSchema } from './Market';
import { StateSchema } from './State';

export const CountrySchema = z.object({
  iso: z.string(),
  iso3: z.string(),
  states_required: z.boolean(),
  zipcode_required: z.boolean(),
  states: z.array(StateSchema).optional(),
  get market() { return MarketSchema.nullable().optional(); },
}) as unknown as z.ZodObject<{
  iso: z.ZodType<Country['iso']>;
  iso3: z.ZodType<Country['iso3']>;
  states_required: z.ZodType<Country['states_required']>;
  zipcode_required: z.ZodType<Country['zipcode_required']>;
  states: z.ZodOptional<z.ZodType<Exclude<Country['states'], undefined>>>;
  market: z.ZodOptional<z.ZodType<Exclude<Country['market'], undefined>>>;
}>;

export type { Country };
