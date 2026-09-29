// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AddressSchema } from './Address';
import { CompanyMembershipSchema } from './CompanyMembership';

export const CompanySchema = z.object({
  id: z.string(),
  name: z.string(),
  kind: z.string(),
  po_number_required: z.boolean(),
  parent_id: z.string().nullable(),
  ancestors: z.array(z.object({ id: z.string(), name: z.string(), kind: z.string() })),
  external_references: z.record(z.string(), z.string()),
  metadata: z.record(z.string(), z.unknown()).nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  children_count: z.number(),
  members_count: z.number(),
  get children() { return z.array(CompanySchema).optional(); },
  addresses: z.array(AddressSchema).optional(),
  memberships: z.array(CompanyMembershipSchema).optional(),
});

export type Company = z.infer<typeof CompanySchema>;
