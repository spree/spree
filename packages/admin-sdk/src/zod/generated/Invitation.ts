// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const InvitationSchema = z.object({
  id: z.string(),
  email: z.string(),
  status: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  expires_at: z.string(),
  role_id: z.string(),
  role_name: z.string(),
  inviter_email: z.string(),
  invitee_exists: z.boolean(),
  store: z.object({ id: z.string(), name: z.string() }),
});

export type Invitation = z.infer<typeof InvitationSchema>;
