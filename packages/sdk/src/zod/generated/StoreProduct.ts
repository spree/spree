// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { StoreImageSchema } from './StoreImage';
import { StoreMetafieldSchema } from './StoreMetafield';
import { StoreOptionTypeSchema } from './StoreOptionType';
import { StorePriceSchema } from './StorePrice';
import { StoreTaxonSchema } from './StoreTaxon';
import { StoreVariantSchema } from './StoreVariant';

export const StoreProductSchema = z.object({
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
  price: StorePriceSchema,
  original_price: StorePriceSchema.nullable(),
  images: z.array(StoreImageSchema).optional(),
  variants: z.array(StoreVariantSchema).optional(),
  default_variant: StoreVariantSchema.optional(),
  master_variant: StoreVariantSchema.optional(),
  option_types: z.array(StoreOptionTypeSchema).optional(),
  taxons: z.array(z.lazy(() => StoreTaxonSchema)).optional(),
  metafields: z.array(StoreMetafieldSchema).optional(),
});

export type StoreProduct = z.infer<typeof StoreProductSchema>;
