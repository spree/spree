// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const EmailAmountLineSchema = z.object({
  label: z.string().nullable(),
  display_amount: z.string(),
  amount: z.string(),
});

export type EmailAmountLine = z.infer<typeof EmailAmountLineSchema>;
