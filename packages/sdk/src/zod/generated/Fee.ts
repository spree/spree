// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const FeeSchema = z.object({
  id: z.string(),
  label: z.string(),
  kind: z.string(),
  line_item_id: z.string().nullable(),
  fulfillment_id: z.string().nullable(),
  amount: z.string().nullable(),
  display_amount: z.string().nullable(),
});

export type Fee = z.infer<typeof FeeSchema>;
