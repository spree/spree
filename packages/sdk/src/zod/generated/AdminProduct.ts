// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AdminImageSchema } from './AdminImage';
import { AdminMetafieldSchema } from './AdminMetafield';
import { AdminOptionTypeSchema } from './AdminOptionType';
import { AdminPriceSchema } from './AdminPrice';
import { AdminShippingCategorySchema } from './AdminShippingCategory';
import { AdminTaxCategorySchema } from './AdminTaxCategory';
import { AdminTaxonSchema } from './AdminTaxon';
import { AdminVariantSchema } from './AdminVariant';

export const AdminProductSchema: z.ZodObject<any> = z.object({
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
  price: z.lazy(() => AdminPriceSchema),
  original_price: z.lazy(() => AdminPriceSchema).nullable(),
  images: z.array(AdminImageSchema).optional(),
  variants: z.array(z.lazy(() => AdminVariantSchema)).optional(),
  default_variant: z.lazy(() => AdminVariantSchema).optional(),
  master_variant: z.lazy(() => AdminVariantSchema).optional(),
  option_types: z.array(z.lazy(() => AdminOptionTypeSchema)).optional(),
  taxons: z.array(z.lazy(() => AdminTaxonSchema)).optional(),
  metafields: z.array(AdminMetafieldSchema).optional(),
  status: z.string(),
  make_active_at: z.string().nullable(),
  discontinue_on: z.string().nullable(),
  meta_title: z.string().nullable(),
  promotionable: z.boolean(),
  total_on_hand: z.number().nullable(),
  deleted_at: z.string().nullable(),
  shipping_category_id: z.string().nullable(),
  tax_category_id: z.string().nullable(),
  cost_price: z.string().nullable(),
  cost_currency: z.string().nullable(),
  shipping_category: AdminShippingCategorySchema.optional(),
  tax_category: AdminTaxCategorySchema.optional(),
});

export type AdminProduct = z.infer<typeof AdminProductSchema>;
