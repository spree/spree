// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { CategorySchema } from './Category';
import { MediaSchema } from './Media';
import { MetafieldSchema } from './Metafield';
import { OptionTypeSchema } from './OptionType';
import { PriceSchema } from './Price';
import { PriceHistorySchema } from './PriceHistory';
import { VariantSchema } from './Variant';

export const ProductSchema = z.object({
  id: z.string(),
  name: z.string(),
  slug: z.string(),
  meta_description: z.string().nullable(),
  meta_keywords: z.string().nullable(),
  variant_count: z.number(),
  available_on: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  purchasable: z.boolean(),
  in_stock: z.boolean(),
  backorderable: z.boolean(),
  available: z.boolean(),
  description: z.string().nullable(),
  description_html: z.string().nullable(),
  default_variant_id: z.string(),
  thumbnail_url: z.string().nullable(),
  tags: z.array(z.string()),
  price: PriceSchema,
  original_price: PriceSchema.nullable(),
  primary_media: MediaSchema.optional(),
  media: z.array(MediaSchema).optional(),
  variants: z.array(VariantSchema).optional(),
  default_variant: VariantSchema.optional(),
  option_types: z.array(OptionTypeSchema).optional(),
  categories: z.array(z.lazy(() => CategorySchema)).optional(),
  metafields: z.array(MetafieldSchema).optional(),
  prior_price: PriceHistorySchema.nullable().optional(),
});

export type Product = z.infer<typeof ProductSchema>;
