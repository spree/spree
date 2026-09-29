// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { StockLocationSchema } from './StockLocation';
import { VariantSchema } from './Variant';

export const StockLevelSchema = z.object({
  id: z.string(),
  count_on_hand: z.number(),
  backorderable: z.boolean(),
  stock_location_id: z.string().nullable(),
  variant_id: z.string().nullable(),
  external_references: z.record(z.string(), z.string()),
  metadata: z.record(z.string(), z.unknown()),
  reserved_count: z.number(),
  incoming_count: z.number(),
  purchasable_count: z.number(),
  variant_name: z.string().nullable(),
  variant_sku: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  stock_location_name: z.string().nullable(),
  product_id: z.string().nullable(),
  options_text: z.string().nullable(),
  thumbnail_url: z.string().nullable(),
  allocated_count: z.number(),
  available_count: z.number(),
  stock_location: StockLocationSchema.optional(),
  get variant() { return VariantSchema.optional(); },
});

export type StockLevel = z.infer<typeof StockLevelSchema>;
