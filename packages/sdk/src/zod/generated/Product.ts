// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { CategorySchema } from './Category';
import { ImageSchema } from './Image';
import { MetafieldSchema } from './Metafield';
import { OptionTypeSchema } from './OptionType';
import { PriceSchema } from './Price';
import { VariantSchema } from './Variant';

export const ProductSchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string().nullable(),
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
  default_variant_id: z.string(),
  thumbnail_url: z.string().nullable(),
  tags: z.array(z.string()),
  price: PriceSchema,
  original_price: PriceSchema.nullable(),
  images: z.array(ImageSchema).optional(),
  variants: z.array(VariantSchema).optional(),
  default_variant: VariantSchema.optional(),
  master_variant: VariantSchema.optional(),
  option_types: z.array(OptionTypeSchema).optional(),
  categories: z.array(z.lazy(() => CategorySchema)).optional(),
  metafields: z.array(MetafieldSchema).optional(),
});

export type Product = z.infer<typeof ProductSchema>;
