// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { StoreShippingMethodSchema } from './StoreShippingMethod';
import { StoreShippingRateSchema } from './StoreShippingRate';
import { StoreStockLocationSchema } from './StoreStockLocation';

export const StoreShipmentSchema = z.object({
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
  shipping_method: StoreShippingMethodSchema,
  stock_location: StoreStockLocationSchema,
  shipping_rates: z.array(StoreShippingRateSchema),
});

export type StoreShipment = z.infer<typeof StoreShipmentSchema>;
