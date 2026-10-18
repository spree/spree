// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type Company from '../../types/generated/Company';
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
}) as unknown as z.ZodObject<{
  id: z.ZodType<Company['id']>;
  name: z.ZodType<Company['name']>;
  kind: z.ZodType<Company['kind']>;
  po_number_required: z.ZodType<Company['po_number_required']>;
  parent_id: z.ZodType<Company['parent_id']>;
  ancestors: z.ZodType<Company['ancestors']>;
  external_references: z.ZodType<Company['external_references']>;
  metadata: z.ZodType<Company['metadata']>;
  created_at: z.ZodType<Company['created_at']>;
  updated_at: z.ZodType<Company['updated_at']>;
  children_count: z.ZodType<Company['children_count']>;
  members_count: z.ZodType<Company['members_count']>;
  children: z.ZodOptional<z.ZodType<Exclude<Company['children'], undefined>>>;
  addresses: z.ZodOptional<z.ZodType<Exclude<Company['addresses'], undefined>>>;
  memberships: z.ZodOptional<z.ZodType<Exclude<Company['memberships'], undefined>>>;
}>;

export type { Company };
