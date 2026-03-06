// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AdminImageSchema } from './AdminImage';
import { AdminMetafieldSchema } from './AdminMetafield';
import { AdminOptionValueSchema } from './AdminOptionValue';
import { AdminPriceSchema } from './AdminPrice';
import { AdminStockItemSchema } from './AdminStockItem';

export const AdminVariantSchema = z.object({
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
  price: AdminPriceSchema,
  original_price: AdminPriceSchema.nullable(),
  images: z.array(AdminImageSchema).optional(),
  option_values: z.array(AdminOptionValueSchema),
  metafields: z.array(AdminMetafieldSchema).optional(),
  position: z.number(),
  tax_category_id: z.string().nullable(),
  cost_price: z.string().nullable(),
  cost_currency: z.string().nullable(),
  deleted_at: z.string().nullable(),
  total_on_hand: z.number().nullable(),
  prices: z.array(AdminPriceSchema).optional(),
  stock_items: z.array(AdminStockItemSchema).optional(),
});

export type AdminVariant = z.infer<typeof AdminVariantSchema>;
