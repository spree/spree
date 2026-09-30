// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const CatalogAssignmentSchema = z.object({
  id: z.string(),
  created_at: z.string(),
  catalog_id: z.string(),
  assignable_type: z.string(),
  assignable_id: z.string(),
  assignable_name: z.string().nullable(),
});

export type CatalogAssignment = z.infer<typeof CatalogAssignmentSchema>;
