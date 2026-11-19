// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { CustomFieldSchema } from './CustomField';

export const CompanySchema = z.object({
  id: z.string(),
  name: z.string(),
  kind: z.string(),
  po_number_required: z.boolean(),
  parent_id: z.string().nullable(),
  ancestors: z.array(z.object({ id: z.string(), name: z.string(), kind: z.string() })),
  custom_fields: z.array(CustomFieldSchema).optional(),
});

export type Company = z.infer<typeof CompanySchema>;
