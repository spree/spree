// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const DeliveryMethodServiceSchema = z.object({
  id: z.string(),
  carrier: z.string(),
  service: z.string(),
  label: z.string().nullable(),
  markup_flat: z.string().nullable(),
  markup_percent: z.string().nullable(),
  position: z.number(),
});

export type DeliveryMethodService = z.infer<typeof DeliveryMethodServiceSchema>;
