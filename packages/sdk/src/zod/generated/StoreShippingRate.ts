// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { StoreShippingMethodSchema } from './StoreShippingMethod';

export const StoreShippingRateSchema = z.object({
  id: z.string(),
  shipping_method_id: z.string(),
  name: z.string(),
  selected: z.boolean(),
  cost: z.number(),
  display_cost: z.string(),
  shipping_method: StoreShippingMethodSchema,
});

export type StoreShippingRate = z.infer<typeof StoreShippingRateSchema>;
