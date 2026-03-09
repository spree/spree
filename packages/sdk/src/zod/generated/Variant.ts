// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ImageSchema } from './Image';
import { MetafieldSchema } from './Metafield';
import { OptionValueSchema } from './OptionValue';
import { PriceSchema } from './Price';

export const VariantSchema = z.object({
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
  price: PriceSchema,
  original_price: PriceSchema.nullable(),
  images: z.array(ImageSchema).optional(),
  option_values: z.array(OptionValueSchema),
  metafields: z.array(MetafieldSchema).optional(),
});

export type Variant = z.infer<typeof VariantSchema>;
