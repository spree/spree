// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { DeliveryMethodSchema } from './DeliveryMethod';
import { FreightSummarySchema } from './FreightSummary';

export const DeliveryRateSchema = z.object({
  id: z.string(),
  delivery_method_id: z.string(),
  name: z.string(),
  selected: z.boolean(),
  cost: z.string().nullable(),
  total: z.string().nullable(),
  additional_tax_total: z.string().nullable(),
  included_tax_total: z.string().nullable(),
  tax_total: z.string().nullable(),
  carrier: z.string().nullable(),
  service_level: z.string().nullable(),
  estimated_delivery_date: z.string().nullable(),
  unpriced: z.boolean(),
  freight_summary: FreightSummarySchema.nullable(),
  display_cost: z.string().nullable(),
  display_total: z.string().nullable(),
  display_additional_tax_total: z.string().nullable(),
  display_included_tax_total: z.string().nullable(),
  display_tax_total: z.string().nullable(),
  delivery_method: DeliveryMethodSchema,
});

export type DeliveryRate = z.infer<typeof DeliveryRateSchema>;
