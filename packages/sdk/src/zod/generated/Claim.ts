// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ClaimLineItemSchema } from './ClaimLineItem';

export const ClaimSchema = z.object({
  id: z.string(),
  number: z.string(),
  status: z.string(),
  claim_type: z.string(),
  resolution: z.string().nullable(),
  order_id: z.string().nullable(),
  reason_id: z.string().nullable(),
  refund_total: z.string(),
  display_refund_total: z.string(),
  approved_at: z.string().nullable(),
  resolved_at: z.string().nullable(),
  denied_at: z.string().nullable(),
  canceled_at: z.string().nullable(),
  claim_line_items: z.array(ClaimLineItemSchema).optional(),
});

export type Claim = z.infer<typeof ClaimSchema>;
