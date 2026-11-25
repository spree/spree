// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PasswordResetAcknowledgementSchema = z.object({
  message: z.string(),
});

export type PasswordResetAcknowledgement = z.infer<typeof PasswordResetAcknowledgementSchema>;
