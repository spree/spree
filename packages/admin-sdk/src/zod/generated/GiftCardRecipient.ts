// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const GiftCardRecipientSchema = z.object({
  id: z.string(),
  email: z.string(),
  name: z.string().nullable(),
  message: z.string().nullable(),
  send_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});

export type GiftCardRecipient = z.infer<typeof GiftCardRecipientSchema>;
