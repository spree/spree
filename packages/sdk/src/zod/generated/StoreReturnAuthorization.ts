// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreReturnAuthorizationSchema = z.object({
  id: z.string(),
  number: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  state: z.string(),
  order_id: z.string().nullable(),
  stock_location_id: z.string().nullable(),
  return_authorization_reason_id: z.string().nullable(),
});

export type StoreReturnAuthorization = z.infer<typeof StoreReturnAuthorizationSchema>;
