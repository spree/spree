// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const OrderChangeActionSchema = z.object({
  id: z.string(),
  kind: z.string(),
  quantity: z.number().nullable(),
  label: z.string().nullable(),
  value_type: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()),
  created_at: z.string(),
  updated_at: z.string(),
  value: z.string().nullable(),
  amount: z.string().nullable(),
  discount_id: z.string().nullable(),
  line_item_id: z.string().nullable(),
  variant_id: z.string().nullable(),
  fulfillment_id: z.string().nullable(),
  delivery_method_id: z.string().nullable(),
});

export type OrderChangeAction = z.infer<typeof OrderChangeActionSchema>;
