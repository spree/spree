// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AdminShippingMethodSchema } from './AdminShippingMethod';

export const AdminShippingRateSchema = z.object({
  id: z.string(),
  shipping_method_id: z.string(),
  name: z.string(),
  selected: z.boolean(),
  cost: z.string(),
  display_cost: z.string(),
  shipping_method: AdminShippingMethodSchema.optional(),
});

export type AdminShippingRate = z.infer<typeof AdminShippingRateSchema>;
