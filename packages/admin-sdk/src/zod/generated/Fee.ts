// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const FeeSchema = z.object({
  id: z.string(),
  label: z.string(),
  kind: z.string(),
  line_item_id: z.string().nullable(),
  fulfillment_id: z.string().nullable(),
  amount: z.string(),
  display_amount: z.string(),
  metadata: z.record(z.string(), z.unknown()).nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});

export type Fee = z.infer<typeof FeeSchema>;
