// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { PriceSchema } from './Price';

export const VolumePriceSchema = z.object({
  id: z.string(),
  name: z.string(),
  min_quantity: z.number(),
  max_quantity: z.number().nullable(),
  price: PriceSchema,
});

export type VolumePrice = z.infer<typeof VolumePriceSchema>;
