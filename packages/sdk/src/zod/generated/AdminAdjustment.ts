// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const AdminAdjustmentSchema = z.object({
  id: z.string(),
  amount: z.string(),
  label: z.string().nullable(),
  eligible: z.boolean(),
  state: z.string(),
  included: z.boolean(),
  created_at: z.string(),
  updated_at: z.string(),
  source_type: z.string().nullable(),
  source_id: z.string().nullable(),
  adjustable_type: z.string().nullable(),
  adjustable_id: z.string().nullable(),
  order_id: z.string().nullable(),
});

export type AdminAdjustment = z.infer<typeof AdminAdjustmentSchema>;
