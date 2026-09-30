// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const CompanyMembershipSchema = z.object({
  id: z.string(),
  company_id: z.string(),
  customer_id: z.string(),
  email: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});

export type CompanyMembership = z.infer<typeof CompanyMembershipSchema>;
