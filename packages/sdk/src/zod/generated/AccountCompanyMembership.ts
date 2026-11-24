// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { CompanySchema } from './Company';

export const AccountCompanyMembershipSchema = z.object({
  id: z.string(),
  company_id: z.string(),
  customer_id: z.string(),
  email: z.string().nullable(),
  company: CompanySchema,
});

export type AccountCompanyMembership = z.infer<typeof AccountCompanyMembershipSchema>;
