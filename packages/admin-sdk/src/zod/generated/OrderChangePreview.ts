// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const OrderChangePreviewSchema = z.object({
  currency: z.string(),
  item_total: z.string().nullable(),
  discount_total: z.string().nullable(),
  delivery_total: z.string().nullable(),
  tax_total: z.string().nullable(),
  included_tax_total: z.string().nullable(),
  additional_tax_total: z.string().nullable(),
  fee_total: z.string().nullable(),
  total: z.string().nullable(),
  previous_total: z.string().nullable(),
  outstanding_balance: z.string().nullable(),
  balance_delta: z.string().nullable(),
});

export type OrderChangePreview = z.infer<typeof OrderChangePreviewSchema>;
