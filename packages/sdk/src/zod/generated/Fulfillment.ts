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
  cost: z.string(),
  display_cost: z.string(),
  total: z.string(),
  display_total: z.string(),
  discount_total: z.string(),
  display_discount_total: z.string(),
  additional_tax_total: z.string(),
  display_additional_tax_total: z.string(),
  included_tax_total: z.string(),
  display_included_tax_total: z.string(),
  tax_total: z.string(),
  display_tax_total: z.string(),
  status: z.string(),
  fulfillment_type: z.string(),
  fulfilled_at: z.string().nullable(),
  items: z.array(z.object({ item_id: z.any() })),
  delivery_method: DeliveryMethodSchema,
  stock_location: StockLocationSchema,
  delivery_rates: z.array(DeliveryRateSchema),
});

export type Fulfillment = z.infer<typeof FulfillmentSchema>;
