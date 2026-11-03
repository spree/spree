// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const EmailReplacementItemSchema = z.object({
  id: z.unknown(),
  quantity: z.unknown(),
  name: z.unknown(),
  options_text: z.unknown(),
});

export type EmailReplacementItem = z.infer<typeof EmailReplacementItemSchema>;
