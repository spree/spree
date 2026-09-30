// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { CustomerSchema } from './Customer';

export const DataRequestSchema = z.object({
  id: z.string(),
  number: z.string(),
  kind: z.string(),
  status: z.string(),
  requested_at: z.string().nullable(),
  completed_at: z.string().nullable(),
  expires_at: z.string().nullable(),
  email: z.string(),
  error_message: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  customer_id: z.string().nullable(),
  requested_by_id: z.string().nullable(),
  get customer() { return CustomerSchema.optional(); },
});

export type DataRequest = z.infer<typeof DataRequestSchema>;
