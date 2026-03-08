// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const AdminPaymentSourceSchema = z.object({
  id: z.string(),
  gateway_payment_profile_id: z.string().nullable(),
});

export type AdminPaymentSource = z.infer<typeof AdminPaymentSourceSchema>;
