// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreNewsletterSubscriberSchema = z.object({
  id: z.string(),
  email: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  verified: z.boolean(),
  verified_at: z.string().nullable(),
  user_id: z.string().nullable(),
});

export type StoreNewsletterSubscriber = z.infer<typeof StoreNewsletterSubscriberSchema>;
