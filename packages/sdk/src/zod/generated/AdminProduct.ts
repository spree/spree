// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AdminMetafieldSchema } from './AdminMetafield';
import { AdminVariantSchema } from './AdminVariant';
import { StoreImageSchema } from './StoreImage';
import { StoreOptionTypeSchema } from './StoreOptionType';
import { StorePriceSchema } from './StorePrice';
import { StoreTaxonSchema } from './StoreTaxon';

export const AdminProductSchema = z.object({
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
  variants: z.array(AdminVariantSchema).optional(),
  default_variant: AdminVariantSchema.optional(),
  master_variant: AdminVariantSchema.optional(),
  option_types: z.array(StoreOptionTypeSchema).optional(),
  taxons: z.array(z.lazy(() => StoreTaxonSchema)).optional(),
  metafields: z.array(AdminMetafieldSchema).optional(),
  status: z.string(),
  make_active_at: z.string().nullable(),
  discontinue_on: z.string().nullable(),
  deleted_at: z.string().nullable(),
  cost_price: z.number().nullable(),
  cost_currency: z.string().nullable(),
});

export type AdminProduct = z.infer<typeof AdminProductSchema>;
