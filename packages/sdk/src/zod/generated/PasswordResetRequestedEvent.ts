// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PasswordResetRequestedEventSchema = z.object({
  id: z.string(),
  email: z.string(),
  reset_token: z.string(),
  store_id: z.string().nullable(),
  redirect_url: z.string().optional(),
});

export type PasswordResetRequestedEvent = z.infer<typeof PasswordResetRequestedEventSchema>;
