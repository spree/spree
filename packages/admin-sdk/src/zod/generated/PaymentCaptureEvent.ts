// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PaymentCaptureEventSchema = z.object({
  id: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  amount: z.string(),
});

export type PaymentCaptureEvent = z.infer<typeof PaymentCaptureEventSchema>;
