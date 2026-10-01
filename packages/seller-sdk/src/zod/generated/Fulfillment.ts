// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { DeliverySchema } from './Delivery';
import { DeliveryRateSchema } from './DeliveryRate';
import { FulfillmentItemSchema } from './FulfillmentItem';
import { ShippingLabelSchema } from './ShippingLabel';

export const FulfillmentSchema = z.object({
  id: z.string(),
  number: z.string(),
  status: z.string(),
  tracking: z.string().nullable(),
  tracking_url: z.string().nullable(),
  fulfilled_at: z.string().nullable(),
  delivered_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  fulfillment_type: z.string().nullable(),
  delivery_method_name: z.string().nullable(),
  stock_location_name: z.string().nullable(),
  stock_location_id: z.string().nullable(),
  fulfillment_items: z.array(FulfillmentItemSchema),
  selected_delivery_rate_id: z.string().nullable(),
  delivery_rates: z.array(DeliveryRateSchema),
  deliveries: z.array(DeliverySchema),
  labels: z.array(ShippingLabelSchema),
});

export type Fulfillment = z.infer<typeof FulfillmentSchema>;
