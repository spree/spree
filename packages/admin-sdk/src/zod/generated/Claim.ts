// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ActorSchema } from './Actor';
import { ClaimLineItemSchema } from './ClaimLineItem';
import { ClaimReasonSchema } from './ClaimReason';
import { OrderSchema } from './Order';
import { RefundSchema } from './Refund';

export const ClaimSchema = z.object({
  id: z.string(),
  number: z.string(),
  status: z.string(),
  resolution: z.string().nullable(),
  order_id: z.string().nullable(),
  reason_id: z.string().nullable(),
  refund_total: z.string(),
  display_refund_total: z.string(),
  approved_at: z.string().nullable(),
  resolved_at: z.string().nullable(),
  denied_at: z.string().nullable(),
  canceled_at: z.string().nullable(),
  reason: ClaimReasonSchema.optional(),
  claim_line_items: z.array(ClaimLineItemSchema).optional(),
  memo: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()),
  created_at: z.string(),
  updated_at: z.string(),
  created_by_id: z.string().nullable(),
  created_by_type: z.string().nullable(),
  created_by: ActorSchema.optional(),
  get order() { return OrderSchema.optional(); },
  get refunds() { return z.array(RefundSchema).optional(); },
});

export type Claim = z.infer<typeof ClaimSchema>;
