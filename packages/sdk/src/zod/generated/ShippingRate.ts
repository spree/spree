// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ShippingMethodSchema } from './ShippingMethod';

export const ShippingRateSchema = z.object({
  id: z.string(),
  shipping_method_id: z.string(),
  name: z.string(),
  selected: z.boolean(),
  cost: z.string(),
  display_cost: z.string(),
  shipping_method: ShippingMethodSchema,
});

export type ShippingRate = z.infer<typeof ShippingRateSchema>;
