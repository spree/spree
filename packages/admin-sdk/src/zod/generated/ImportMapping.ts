// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ImportMappingSchema = z.object({
  id: z.string(),
  schema_field: z.string(),
  file_column: z.string().nullable(),
  required: z.boolean(),
});

export type ImportMapping = z.infer<typeof ImportMappingSchema>;
