// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { FreightSummaryLineSchema } from './FreightSummaryLine';

export const FreightSummarySchema = z.object({
  total_units: z.number(),
  total_cartons: z.number(),
  total_pallets: z.number().nullable(),
  total_volume: z.string(),
  total_weight: z.string(),
  complete: z.boolean(),
  lines: z.array(FreightSummaryLineSchema),
});

export type FreightSummary = z.infer<typeof FreightSummarySchema>;
