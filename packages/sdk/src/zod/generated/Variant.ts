// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { MediaSchema } from './Media';
import { MetafieldSchema } from './Metafield';
import { OptionValueSchema } from './OptionValue';
import { PriceSchema } from './Price';
import { PriceHistorySchema } from './PriceHistory';

export const VariantSchema = z.object({
  id: z.string(),
  product_id: z.string(),
  sku: z.string().nullable(),
  options_text: z.string(),
  track_inventory: z.boolean(),
  media_count: z.number(),
  created_at: z.string(),
  updated_at: z.string(),
  thumbnail_url: z.string().nullable(),
  purchasable: z.boolean(),
  in_stock: z.boolean(),
  backorderable: z.boolean(),
  weight: z.number().nullable(),
  height: z.number().nullable(),
  width: z.number().nullable(),
  depth: z.number().nullable(),
  price: PriceSchema,
  original_price: PriceSchema.nullable(),
  primary_media: MediaSchema.optional(),
  media: z.array(MediaSchema).optional(),
  option_values: z.array(OptionValueSchema),
  metafields: z.array(MetafieldSchema).optional(),
  prior_price: PriceHistorySchema.nullable().optional(),
});

export type Variant = z.infer<typeof VariantSchema>;
