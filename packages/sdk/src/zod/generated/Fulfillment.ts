// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { DeliveryMethodSchema } from './DeliveryMethod';
import { DeliveryRateSchema } from './DeliveryRate';
import { StockLocationSchema } from './StockLocation';

export const FulfillmentSchema = z.object({
  id: z.string(),
  number: z.string(),
  tracking: z.string().nullable(),
  tracking_url: z.string().nullable(),
  cost: z.string().nullable(),
  display_cost: z.string().nullable(),
  total: z.string().nullable(),
  display_total: z.string().nullable(),
  discount_total: z.string().nullable(),
  display_discount_total: z.string().nullable(),
  additional_tax_total: z.string().nullable(),
  display_additional_tax_total: z.string().nullable(),
  included_tax_total: z.string().nullable(),
  display_included_tax_total: z.string().nullable(),
  tax_total: z.string().nullable(),
  display_tax_total: z.string().nullable(),
  status: z.string(),
  fulfillment_type: z.string(),
  fulfilled_at: z.string().nullable(),
  items: z.array(z.object({ item_id: z.any() })),
  delivery_method: DeliveryMethodSchema,
  stock_location: StockLocationSchema,
  delivery_rates: z.array(DeliveryRateSchema),
});

export type Fulfillment = z.infer<typeof FulfillmentSchema>;
