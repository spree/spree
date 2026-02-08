// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { StoreImageSchema } from './StoreImage';
import { StoreMetafieldSchema } from './StoreMetafield';
import { StoreOptionValueSchema } from './StoreOptionValue';
import { StorePriceSchema } from './StorePrice';

export const StoreVariantSchema = z.object({
  id: z.string(),
  product_id: z.string(),
  sku: z.string().nullable(),
  is_master: z.boolean(),
  options_text: z.string(),
  track_inventory: z.boolean(),
  image_count: z.number(),
  created_at: z.string(),
  updated_at: z.string(),
  thumbnail: z.string().nullable(),
  purchasable: z.boolean(),
  in_stock: z.boolean(),
  backorderable: z.boolean(),
  weight: z.number().nullable(),
  height: z.number().nullable(),
  width: z.number().nullable(),
  depth: z.number().nullable(),
  price: StorePriceSchema,
  original_price: StorePriceSchema.nullable(),
  images: z.array(StoreImageSchema).optional(),
  option_values: z.array(StoreOptionValueSchema),
  metafields: z.array(StoreMetafieldSchema).optional(),
});

export type StoreVariant = z.infer<typeof StoreVariantSchema>;
