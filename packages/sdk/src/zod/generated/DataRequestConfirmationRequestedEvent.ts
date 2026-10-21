// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const DataRequestConfirmationRequestedEventSchema = z.object({
  id: z.string(),
  number: z.string(),
  kind: z.string(),
  status: z.string(),
  requested_at: z.string().nullable(),
  completed_at: z.string().nullable(),
  email: z.string(),
  confirmation_token: z.string(),
  store_id: z.string(),
  redirect_url: z.string().optional(),
});

export type DataRequestConfirmationRequestedEvent = z.infer<typeof DataRequestConfirmationRequestedEventSchema>;
