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
  final_price: z.string(),
  display_final_price: z.string(),
  free: z.boolean(),
  status: z.string(),
  fulfillment_type: z.string(),
  fulfilled_at: z.string().nullable(),
  items: z.array(z.object({ item_id: z.any() })),
  delivery_method: DeliveryMethodSchema,
  stock_location: StockLocationSchema,
  delivery_rates: z.array(DeliveryRateSchema),
});

export type Fulfillment = z.infer<typeof FulfillmentSchema>;
