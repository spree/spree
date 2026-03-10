import { z } from 'zod/v4'

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

  // Pricing (master variant)
  price: z.coerce.number().optional(),
  compare_at_price: z.coerce.number().nullable().optional(),
  cost_price: z.coerce.number().nullable().optional(),

  // Inventory (master variant)
  sku: z.string().optional(),
  barcode: z.string().optional(),
  track_inventory: z.boolean().optional(),

  // Shipping
  shipping_category_id: z.string().nullable().optional(),
  weight: z.coerce.number().nullable().optional(),
  height: z.coerce.number().nullable().optional(),
  width: z.coerce.number().nullable().optional(),
  depth: z.coerce.number().nullable().optional(),
  weight_unit: z.string().nullable().optional(),
  dimensions_unit: z.string().nullable().optional(),

  // Tax
  tax_category_id: z.string().nullable().optional(),

  // SEO
  meta_title: z.string().optional(),
  meta_description: z.string().optional(),
  slug: z.string().optional(),
})

export type ProductFormValues = z.infer<typeof productFormSchema>
