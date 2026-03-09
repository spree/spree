// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const InvitationSchema = z.object({
  id: z.string(),
  email: z.string(),
  resource_type: z.string().nullable(),
  inviter_type: z.string().nullable(),
  invitee_type: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  status: z.string(),
  resource_id: z.string().nullable(),
  inviter_id: z.string().nullable(),
  invitee_id: z.string().nullable(),
  role_id: z.string().nullable(),
  expires_at: z.string().nullable(),
  accepted_at: z.string().nullable(),
});

export type Invitation = z.infer<typeof InvitationSchema>;
