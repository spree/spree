// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const CompanyInvitationDetailsSchema = z.object({
  id: z.string(),
  email: z.string(),
  expires_at: z.string().nullable(),
  company_id: z.string(),
  status: z.string(),
  company_name: z.string(),
  store_name: z.string(),
});

export type CompanyInvitationDetails = z.infer<typeof CompanyInvitationDetailsSchema>;
