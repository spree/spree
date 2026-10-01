// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { EmailDeliverySchema } from './EmailDelivery';
import { EmailDeliveryMethodSchema } from './EmailDeliveryMethod';
import { EmailDeliveryRateSchema } from './EmailDeliveryRate';
import { EmailParcelItemSchema } from './EmailParcelItem';
import { EmailStockLocationSchema } from './EmailStockLocation';

export const EmailFulfillmentSchema = z.object({
  id: z.string(),
  number: z.string(),
  tracking: z.string().nullable(),
  tracking_url: z.string().nullable(),
  pickup_point_data: z.record(z.string(), z.unknown()).nullable(),
  selected_delivery_rate_id: z.string().nullable(),
  unpriced: z.boolean(),
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
  delivered_at: z.string().nullable(),
  items: z.array(z.object({ item_id: z.string(), variant_id: z.string(), quantity: z.number() })),
  deliveries: z.array(EmailDeliverySchema),
  delivery_method: EmailDeliveryMethodSchema,
  stock_location: EmailStockLocationSchema,
  delivery_rates: z.array(EmailDeliveryRateSchema),
  delivery_method_name: z.string().nullable(),
  manifest_items: z.array(EmailParcelItemSchema),
});

export type EmailFulfillment = z.infer<typeof EmailFulfillmentSchema>;
