// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { CustomFieldSchema } from './CustomField';
import { MediaSchema } from './Media';
import { OptionValueSchema } from './OptionValue';
import { PriceSchema } from './Price';
import { PriceHistorySchema } from './PriceHistory';
import { SellerSchema } from './Seller';
import { StockLevelSchema } from './StockLevel';

export const VariantSchema = z.object({
  id: z.string(),
  product_id: z.string(),
  sku: z.string().nullable(),
  options_text: z.string(),
  track_inventory: z.boolean(),
  media_count: z.number(),
  preorder_ships_at: z.string().nullable(),
  thumbnail_url: z.string().nullable(),
  purchasable: z.boolean(),
  in_stock: z.boolean(),
  backorderable: z.boolean(),
  preorder: z.boolean(),
  weight: z.number().nullable(),
  height: z.number().nullable(),
  width: z.number().nullable(),
  depth: z.number().nullable(),
  weight_unit: z.string(),
  dimensions_unit: z.string(),
  minimum_order_quantity: z.number().nullable(),
  order_multiple: z.number().nullable(),
  purchase_unit: z.string().nullable(),
  units_per_carton: z.number().nullable(),
  price: PriceSchema,
  original_price: PriceSchema.nullable(),
  seller_id: z.string().nullable(),
  seller: SellerSchema.optional(),
  primary_media: MediaSchema.optional(),
  media: z.array(MediaSchema).optional(),
  option_values: z.array(OptionValueSchema),
  custom_fields: z.array(CustomFieldSchema).optional(),
  prior_price: PriceHistorySchema.nullable().optional(),
  metadata: z.record(z.string(), z.unknown()),
  position: z.number(),
  cost_price: z.string().nullable(),
  cost_currency: z.string().nullable(),
  barcode: z.string().nullable(),
  backorder_limit: z.number().nullable(),
  hs_code: z.string().nullable(),
  country_of_origin: z.string().nullable(),
  customs_description: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  preorderable: z.boolean(),
  available_stock: z.number().nullable(),
  total_on_hand: z.number().nullable(),
  prices: z.array(PriceSchema).optional(),
  stock_levels: z.array(StockLevelSchema).optional(),
});

export type Variant = z.infer<typeof VariantSchema>;
