// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const SessionSchema = z.object({
  id: z.string(),
  ip_address: z.string().nullable(),
  user_agent: z.string().nullable(),
  last_active_at: z.string(),
});

export type Session = z.infer<typeof SessionSchema>;
