// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AdminImageSchema } from './AdminImage';
import { AdminMetafieldSchema } from './AdminMetafield';
import { AdminOptionTypeSchema } from './AdminOptionType';
import { AdminPriceSchema } from './AdminPrice';
import { AdminTaxonSchema } from './AdminTaxon';
import { AdminVariantSchema } from './AdminVariant';

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
  price: AdminPriceSchema,
  original_price: AdminPriceSchema.nullable(),
  images: z.array(AdminImageSchema).optional(),
  variants: z.array(AdminVariantSchema).optional(),
  default_variant: AdminVariantSchema.optional(),
  master_variant: AdminVariantSchema.optional(),
  option_types: z.array(AdminOptionTypeSchema).optional(),
  taxons: z.array(z.lazy(() => AdminTaxonSchema)).optional(),
  metafields: z.array(AdminMetafieldSchema).optional(),
  status: z.string(),
  make_active_at: z.string().nullable(),
  discontinue_on: z.string().nullable(),
  deleted_at: z.string().nullable(),
  cost_price: z.string().nullable(),
  cost_currency: z.string().nullable(),
});

export type AdminProduct = z.infer<typeof AdminProductSchema>;
