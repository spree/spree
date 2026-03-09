// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ShippingMethodSchema } from './ShippingMethod';
import { ShippingRateSchema } from './ShippingRate';
import { StockLocationSchema } from './StockLocation';

export const ShipmentSchema = z.object({
  id: z.string(),
  number: z.string(),
  state: z.string(),
  tracking: z.string().nullable(),
  tracking_url: z.string().nullable(),
  cost: z.string(),
  display_cost: z.string(),
  shipped_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  shipping_method: ShippingMethodSchema,
  stock_location: StockLocationSchema,
  shipping_rates: z.array(ShippingRateSchema),
});

export type Shipment = z.infer<typeof ShipmentSchema>;
