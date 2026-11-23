// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type CompanyMembership from '../../types/generated/CompanyMembership';
import { CustomerSchema } from './Customer';

export const CompanyMembershipSchema = z.object({
  id: z.string(),
  company_id: z.string(),
  customer_id: z.string(),
  email: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  get customer() { return CustomerSchema.optional(); },
}) as unknown as z.ZodObject<{
  id: z.ZodType<CompanyMembership['id']>;
  company_id: z.ZodType<CompanyMembership['company_id']>;
  customer_id: z.ZodType<CompanyMembership['customer_id']>;
  email: z.ZodType<CompanyMembership['email']>;
  created_at: z.ZodType<CompanyMembership['created_at']>;
  updated_at: z.ZodType<CompanyMembership['updated_at']>;
  customer: z.ZodOptional<z.ZodType<Exclude<CompanyMembership['customer'], undefined>>>;
}>;

export type { CompanyMembership };
