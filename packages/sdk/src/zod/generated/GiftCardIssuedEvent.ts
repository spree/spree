// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { CustomFieldSchema } from './CustomField';
import { GiftCardRecipientSchema } from './GiftCardRecipient';

export const GiftCardIssuedEventSchema = z.object({
  id: z.string(),
  code: z.string(),
  status: z.string(),
  currency: z.string(),
  amount: z.string().nullable(),
  amount_used: z.string().nullable(),
  amount_authorized: z.string().nullable(),
  amount_remaining: z.string().nullable(),
  display_amount: z.string().nullable(),
  display_amount_used: z.string().nullable(),
  display_amount_remaining: z.string().nullable(),
  expires_at: z.string().nullable(),
  redeemed_at: z.string().nullable(),
  expired: z.boolean(),
  active: z.boolean(),
  custom_fields: z.array(CustomFieldSchema).optional(),
  line_item_id: z.string().nullable(),
  order_id: z.string().nullable(),
  recipient: GiftCardRecipientSchema.nullable(),
});

export type GiftCardIssuedEvent = z.infer<typeof GiftCardIssuedEventSchema>;
