import { z } from 'zod/v4'

export const stockItemFormSchema = z.object({
  stock_location_id: z.string(),
  stock_location_name: z.string().optional(),
  count_on_hand: z.coerce.number().int(),
  backorderable: z.boolean(),
})

export type StockItemFormValues = z.infer<typeof stockItemFormSchema>

export const variantInventoryFormSchema = z.object({
  id: z.string(),
  sku: z.string().nullable().optional(),
  options_text: z.string().nullable().optional(),
  stock_items: z.array(stockItemFormSchema),
})

export type VariantInventoryFormValues = z.infer<typeof variantInventoryFormSchema>

export const productFormSchema = z.object({
  // General
  name: z.string().min(1, 'Name is required'),
  description: z.string().optional(),

  // Status
  status: z.enum(['draft', 'active', 'archived']).optional(),
  make_active_at: z.string().nullable().optional(),
  available_on: z.string().nullable().optional(),
  discontinue_on: z.string().nullable().optional(),

  // Categorization
  category_ids: z.array(z.string()).optional(),
  tags: z.array(z.string()).optional(),

  // Tax
  tax_category_id: z.string().nullable().optional(),

  // SEO
  meta_title: z.string().optional(),
  meta_description: z.string().optional(),
  slug: z.string().optional(),

  // Per-variant inventory across stock locations. For single-variant products
  // this carries one entry (the default variant).
  variants_inventory: z.array(variantInventoryFormSchema).optional(),
})

export type ProductFormValues = z.infer<typeof productFormSchema>
