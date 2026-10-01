// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const DeliveryProfileSchema = z.object({
  id: z.string(),
  name: z.string(),
  default: z.boolean(),
  digital: z.boolean(),
});

export type DeliveryProfile = z.infer<typeof DeliveryProfileSchema>;
