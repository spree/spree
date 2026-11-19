// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type Fulfillment from '../../types/generated/Fulfillment';
import { CustomFieldSchema } from './CustomField';
import { DeliverySchema } from './Delivery';
import { DeliveryMethodSchema } from './DeliveryMethod';
import { DeliveryRateSchema } from './DeliveryRate';
import { FulfillmentItemSchema } from './FulfillmentItem';
import { OrderSchema } from './Order';
import { ShippingLabelSchema } from './ShippingLabel';
import { StockLocationSchema } from './StockLocation';
import { TaxLineSchema } from './TaxLine';

export const FulfillmentSchema = z.object({
  id: z.string(),
  number: z.string(),
  tracking: z.string().nullable(),
  tracking_url: z.string().nullable(),
  pickup_point_data: z.record(z.string(), z.unknown()).nullable(),
  selected_delivery_rate_id: z.string().nullable(),
  unpriced: z.boolean(),
  cost: z.string(),
  total: z.string(),
  discount_total: z.string(),
  additional_tax_total: z.string(),
  included_tax_total: z.string(),
  tax_total: z.string(),
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
  custom_fields: z.array(CustomFieldSchema).optional(),
  external_references: z.record(z.string(), z.string()),
  metadata: z.record(z.string(), z.unknown()),
  created_at: z.string(),
  updated_at: z.string(),
  adjustment_total: z.string(),
  pre_tax_amount: z.string(),
  order_id: z.string().nullable(),
  stock_location_id: z.string().nullable(),
  documents: z.array(z.object({ kind: z.string(), url: z.string() })),
  labels: z.array(ShippingLabelSchema),
  provider_generates_labels: z.boolean(),
  fulfillment_items: z.array(FulfillmentItemSchema).optional(),
  get order() { return OrderSchema.optional(); },
}) as unknown as z.ZodObject<{
  id: z.ZodType<Fulfillment['id']>;
  number: z.ZodType<Fulfillment['number']>;
  tracking: z.ZodType<Fulfillment['tracking']>;
  tracking_url: z.ZodType<Fulfillment['tracking_url']>;
  pickup_point_data: z.ZodType<Fulfillment['pickup_point_data']>;
  selected_delivery_rate_id: z.ZodType<Fulfillment['selected_delivery_rate_id']>;
  unpriced: z.ZodType<Fulfillment['unpriced']>;
  cost: z.ZodType<Fulfillment['cost']>;
  total: z.ZodType<Fulfillment['total']>;
  discount_total: z.ZodType<Fulfillment['discount_total']>;
  additional_tax_total: z.ZodType<Fulfillment['additional_tax_total']>;
  included_tax_total: z.ZodType<Fulfillment['included_tax_total']>;
  tax_total: z.ZodType<Fulfillment['tax_total']>;
  status: z.ZodType<Fulfillment['status']>;
  fulfillment_type: z.ZodType<Fulfillment['fulfillment_type']>;
  fulfilled_at: z.ZodType<Fulfillment['fulfilled_at']>;
  delivered_at: z.ZodType<Fulfillment['delivered_at']>;
  items: z.ZodType<Fulfillment['items']>;
  deliveries: z.ZodType<Fulfillment['deliveries']>;
  delivery_method: z.ZodOptional<z.ZodType<Exclude<Fulfillment['delivery_method'], undefined>>>;
  stock_location: z.ZodOptional<z.ZodType<Exclude<Fulfillment['stock_location'], undefined>>>;
  delivery_rates: z.ZodOptional<z.ZodType<Exclude<Fulfillment['delivery_rates'], undefined>>>;
  tax_lines: z.ZodOptional<z.ZodType<Exclude<Fulfillment['tax_lines'], undefined>>>;
  custom_fields: z.ZodOptional<z.ZodType<Exclude<Fulfillment['custom_fields'], undefined>>>;
  external_references: z.ZodType<Fulfillment['external_references']>;
  metadata: z.ZodType<Fulfillment['metadata']>;
  created_at: z.ZodType<Fulfillment['created_at']>;
  updated_at: z.ZodType<Fulfillment['updated_at']>;
  adjustment_total: z.ZodType<Fulfillment['adjustment_total']>;
  pre_tax_amount: z.ZodType<Fulfillment['pre_tax_amount']>;
  order_id: z.ZodType<Fulfillment['order_id']>;
  stock_location_id: z.ZodType<Fulfillment['stock_location_id']>;
  documents: z.ZodType<Fulfillment['documents']>;
  labels: z.ZodType<Fulfillment['labels']>;
  provider_generates_labels: z.ZodType<Fulfillment['provider_generates_labels']>;
  fulfillment_items: z.ZodOptional<z.ZodType<Exclude<Fulfillment['fulfillment_items'], undefined>>>;
  order: z.ZodOptional<z.ZodType<Exclude<Fulfillment['order'], undefined>>>;
}>;

export type { Fulfillment };
