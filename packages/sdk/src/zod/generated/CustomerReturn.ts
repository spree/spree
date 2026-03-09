// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const CustomerReturnSchema = z.object({
  id: z.string(),
  number: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  stock_location_id: z.string().nullable(),
});

export type CustomerReturn = z.infer<typeof CustomerReturnSchema>;
