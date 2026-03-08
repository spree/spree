// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const AdminPaymentMethodSchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  type: z.string(),
  session_required: z.boolean(),
  active: z.boolean(),
  auto_capture: z.boolean().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});

export type AdminPaymentMethod = z.infer<typeof AdminPaymentMethodSchema>;
