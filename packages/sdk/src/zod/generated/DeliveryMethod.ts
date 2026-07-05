// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const DeliveryMethodSchema = z.object({
  id: z.string(),
  name: z.string(),
  code: z.string().nullable(),
});

export type DeliveryMethod = z.infer<typeof DeliveryMethodSchema>;
