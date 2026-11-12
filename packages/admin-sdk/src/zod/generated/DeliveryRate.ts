// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { DeliveryMethodSchema } from './DeliveryMethod';
import { FreightSummarySchema } from './FreightSummary';

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
  carrier: z.string().nullable(),
  service_level: z.string().nullable(),
  estimated_delivery_date: z.string().nullable(),
  unpriced: z.boolean(),
  freight_summary: FreightSummarySchema.nullable(),
  delivery_method: DeliveryMethodSchema.optional(),
  metadata: z.record(z.string(), z.unknown()).nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});

export type DeliveryRate = z.infer<typeof DeliveryRateSchema>;
