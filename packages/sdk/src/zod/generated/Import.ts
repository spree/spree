// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

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
});

export type Import = z.infer<typeof ImportSchema>;
