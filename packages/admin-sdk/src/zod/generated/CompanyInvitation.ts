// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const CompanyInvitationSchema = z.object({
  id: z.string(),
  email: z.string(),
  expires_at: z.string().nullable(),
  company_id: z.string(),
  status: z.string(),
  accepted_at: z.string().nullable(),
  revoked_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});

export type CompanyInvitation = z.infer<typeof CompanyInvitationSchema>;
