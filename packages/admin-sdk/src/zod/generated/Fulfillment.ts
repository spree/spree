// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { DeliverySchema } from './Delivery';
import { DeliveryMethodSchema } from './DeliveryMethod';
import { DeliveryRateSchema } from './DeliveryRate';
import { FulfillmentItemSchema } from './FulfillmentItem';
import { OrderSchema } from './Order';
import { ShippingLabelSchema } from './ShippingLabel';
import { StockLocationSchema } from './StockLocation';
import { TaxLineSchema } from './TaxLine';

export const FulfillmentSchema: z.ZodObject<any> = z.object({
  id: z.string(),
  number: z.string(),
  tracking: z.string().nullable(),
  tracking_url: z.string().nullable(),
  pickup_point_data: z.record(z.string(), z.unknown()).nullable(),
  selected_delivery_rate_id: z.string().nullable(),
  unpriced: z.boolean(),
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
  delivered_at: z.string().nullable(),
  items: z.array(z.object({ item_id: z.string(), variant_id: z.string(), quantity: z.number() })),
  deliveries: z.array(DeliverySchema),
  delivery_method: DeliveryMethodSchema.optional(),
  stock_location: StockLocationSchema.optional(),
  delivery_rates: z.array(DeliveryRateSchema).optional(),
  tax_lines: z.array(TaxLineSchema).optional(),
  metadata: z.record(z.string(), z.unknown()),
  adjustment_total: z.string(),
  pre_tax_amount: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  order_id: z.string().nullable(),
  stock_location_id: z.string().nullable(),
  documents: z.array(z.object({ kind: z.string(), url: z.string() })),
  labels: z.array(ShippingLabelSchema),
  provider_generates_labels: z.boolean(),
  fulfillment_items: z.array(FulfillmentItemSchema).optional(),
  order: z.lazy(() => OrderSchema).optional(),
});

export type Fulfillment = z.infer<typeof FulfillmentSchema>;
