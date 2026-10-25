// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const NewsletterSubscriberRequestEventSchema = z.object({
  id: z.string(),
  email: z.string(),
  verification_token: z.string().optional(),
  unsubscribe_token: z.string(),
  store_id: z.string().nullable(),
  customer_id: z.string().nullable(),
  redirect_url: z.string().optional(),
});

export type NewsletterSubscriberRequestEvent = z.infer<typeof NewsletterSubscriberRequestEventSchema>;
