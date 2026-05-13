import { z } from 'zod/v4'

export const priceSchema = z.object({
  currency: z.string(),
  amount: z.coerce.number().nullable().optional(),
  compare_at_amount: z.coerce.number().nullable().optional(),
})

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
})

export type ProductFormValues = z.infer<typeof productFormSchema>
