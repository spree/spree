// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreReportSchema = z.object({
  id: z.string(),
  type: z.string().nullable(),
  currency: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  user_id: z.string().nullable(),
  date_from: z.string().nullable(),
  date_to: z.string().nullable(),
});

export type StoreReport = z.infer<typeof StoreReportSchema>;
