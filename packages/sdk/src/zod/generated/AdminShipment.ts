// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AdminAdjustmentSchema } from './AdminAdjustment';
import { AdminOrderSchema } from './AdminOrder';
import { StoreShippingMethodSchema } from './StoreShippingMethod';
import { StoreShippingRateSchema } from './StoreShippingRate';
import { StoreStockLocationSchema } from './StoreStockLocation';

export const AdminShipmentSchema: z.ZodObject<any> = z.object({
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
  adjustment_total: z.string(),
  additional_tax_total: z.string(),
  included_tax_total: z.string(),
  promo_total: z.string(),
  pre_tax_amount: z.string(),
  metadata: z.record(z.string(), z.unknown()).nullable(),
  order_id: z.string().nullable(),
  stock_location_id: z.string().nullable(),
  order: z.lazy(() => AdminOrderSchema).optional(),
  adjustments: z.array(z.lazy(() => AdminAdjustmentSchema)).optional(),
});

export type AdminShipment = z.infer<typeof AdminShipmentSchema>;
