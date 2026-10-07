// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const FreightSummaryLineSchema = z.object({
  variant_id: z.string().nullable(),
  sku: z.string().nullable(),
  name: z.string().nullable(),
  units: z.number(),
  cartons: z.number().nullable(),
  pallets: z.number().nullable(),
  units_per_carton: z.number().nullable(),
  cartons_per_pallet: z.number().nullable(),
  complete: z.boolean(),
  weight_per_carton: z.string().nullable(),
  volume: z.string(),
  weight: z.string(),
});

export type FreightSummaryLine = z.infer<typeof FreightSummaryLineSchema>;
