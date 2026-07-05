// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { DeliveryMethodSchema } from './DeliveryMethod';

export const DeliveryRateSchema = z.object({
  id: z.string(),
  delivery_method_id: z.string(),
  name: z.string(),
  selected: z.boolean(),
  cost: z.string(),
  total: z.string(),
  additional_tax_total: z.string(),
  included_tax_total: z.string(),
  tax_total: z.string(),
  display_cost: z.string(),
  display_total: z.string(),
  display_additional_tax_total: z.string(),
  display_included_tax_total: z.string(),
  display_tax_total: z.string(),
  delivery_method: DeliveryMethodSchema,
});

export type DeliveryRate = z.infer<typeof DeliveryRateSchema>;
