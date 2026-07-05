// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ReturnAuthorizationSchema = z.object({
  id: z.string(),
  number: z.string(),
  status: z.string(),
  order_id: z.string().nullable(),
  stock_location_id: z.string().nullable(),
  return_authorization_reason_id: z.string().nullable(),
});

export type ReturnAuthorization = z.infer<typeof ReturnAuthorizationSchema>;
