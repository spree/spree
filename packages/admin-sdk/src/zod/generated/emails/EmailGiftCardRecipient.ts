// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const EmailGiftCardRecipientSchema = z.object({
  id: z.string(),
  email: z.string(),
  name: z.string().nullable(),
  message: z.string().nullable(),
  send_at: z.string().nullable(),
});

export type EmailGiftCardRecipient = z.infer<typeof EmailGiftCardRecipientSchema>;
