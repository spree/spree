// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { CompanySchema } from './Company';

export const CompanyInvitationSchema = z.object({
  id: z.string(),
  email: z.string(),
  expires_at: z.string().nullable(),
  company_id: z.string(),
  status: z.string(),
  company: CompanySchema.optional(),
  company_name: z.string().optional(),
  store_name: z.string().optional(),
});

export type CompanyInvitation = z.infer<typeof CompanyInvitationSchema>;
