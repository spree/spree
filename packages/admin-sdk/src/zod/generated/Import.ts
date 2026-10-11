// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ImportMappingSchema } from './ImportMapping';

export const ImportSchema = z.object({
  id: z.string(),
  number: z.string(),
  rows_count: z.number(),
  created_at: z.string(),
  updated_at: z.string(),
  type: z.string().nullable(),
  status: z.string(),
  store_id: z.string().nullable(),
  seller_id: z.string().nullable(),
  owner_type: z.string().nullable(),
  owner_id: z.string().nullable(),
  user_id: z.string().nullable(),
  processing_errors: z.string().nullable(),
  delimiter: z.string(),
  price_list_id: z.string().nullable(),
  seller_name: z.string().nullable(),
  original_filename: z.string().nullable(),
  original_byte_size: z.number().nullable(),
  original_file_url: z.string().nullable(),
  completed_rows_count: z.number(),
  failed_rows_count: z.number(),
  schema_fields: z.array(z.object({ name: z.string(), label: z.string(), required: z.boolean() })),
  csv_headers: z.array(z.string()),
  sample_row: z.record(z.string(), z.string().nullable()),
  mappings: z.array(ImportMappingSchema),
});

export type Import = z.infer<typeof ImportSchema>;
