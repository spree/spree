// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type StockLevel from '../../types/generated/StockLevel';
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
}) as unknown as z.ZodObject<{
  id: z.ZodType<StockLevel['id']>;
  count_on_hand: z.ZodType<StockLevel['count_on_hand']>;
  backorderable: z.ZodType<StockLevel['backorderable']>;
  stock_location_id: z.ZodType<StockLevel['stock_location_id']>;
  variant_id: z.ZodType<StockLevel['variant_id']>;
  external_references: z.ZodType<StockLevel['external_references']>;
  metadata: z.ZodType<StockLevel['metadata']>;
  reserved_count: z.ZodType<StockLevel['reserved_count']>;
  incoming_count: z.ZodType<StockLevel['incoming_count']>;
  purchasable_count: z.ZodType<StockLevel['purchasable_count']>;
  variant_name: z.ZodType<StockLevel['variant_name']>;
  variant_sku: z.ZodType<StockLevel['variant_sku']>;
  created_at: z.ZodType<StockLevel['created_at']>;
  updated_at: z.ZodType<StockLevel['updated_at']>;
  stock_location_name: z.ZodType<StockLevel['stock_location_name']>;
  product_id: z.ZodType<StockLevel['product_id']>;
  options_text: z.ZodType<StockLevel['options_text']>;
  thumbnail_url: z.ZodType<StockLevel['thumbnail_url']>;
  allocated_count: z.ZodType<StockLevel['allocated_count']>;
  available_count: z.ZodType<StockLevel['available_count']>;
  stock_location: z.ZodOptional<z.ZodType<Exclude<StockLevel['stock_location'], undefined>>>;
  variant: z.ZodOptional<z.ZodType<Exclude<StockLevel['variant'], undefined>>>;
}>;

export type { StockLevel };
