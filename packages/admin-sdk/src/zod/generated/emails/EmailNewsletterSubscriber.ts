// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const EmailNewsletterSubscriberSchema = z.object({
  id: z.string(),
  email: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  verified: z.boolean(),
  verified_at: z.string().nullable(),
  customer_id: z.string().nullable(),
});

export type EmailNewsletterSubscriber = z.infer<typeof EmailNewsletterSubscriberSchema>;
