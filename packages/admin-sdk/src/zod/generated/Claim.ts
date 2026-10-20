// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type Claim from '../../types/generated/Claim';
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
}) as unknown as z.ZodObject<{
  id: z.ZodType<Claim['id']>;
  number: z.ZodType<Claim['number']>;
  status: z.ZodType<Claim['status']>;
  resolution: z.ZodType<Claim['resolution']>;
  order_id: z.ZodType<Claim['order_id']>;
  reason_id: z.ZodType<Claim['reason_id']>;
  refund_total: z.ZodType<Claim['refund_total']>;
  approved_at: z.ZodType<Claim['approved_at']>;
  resolved_at: z.ZodType<Claim['resolved_at']>;
  denied_at: z.ZodType<Claim['denied_at']>;
  canceled_at: z.ZodType<Claim['canceled_at']>;
  reason: z.ZodOptional<z.ZodType<Exclude<Claim['reason'], undefined>>>;
  claim_line_items: z.ZodOptional<z.ZodType<Exclude<Claim['claim_line_items'], undefined>>>;
  memo: z.ZodType<Claim['memo']>;
  metadata: z.ZodType<Claim['metadata']>;
  created_at: z.ZodType<Claim['created_at']>;
  updated_at: z.ZodType<Claim['updated_at']>;
  created_by_id: z.ZodType<Claim['created_by_id']>;
  created_by_type: z.ZodType<Claim['created_by_type']>;
  created_by: z.ZodOptional<z.ZodType<Exclude<Claim['created_by'], undefined>>>;
  order: z.ZodOptional<z.ZodType<Exclude<Claim['order'], undefined>>>;
  refunds: z.ZodOptional<z.ZodType<Exclude<Claim['refunds'], undefined>>>;
}>;

export type { Claim };
