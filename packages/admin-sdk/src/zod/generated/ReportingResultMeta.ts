// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ReportingResultMetaSchema = z.object({
  currency: z.string(),
  time_range: z.object({ since: z.string(), until: z.string() }),
  previous_time_range: z.object({ since: z.string(), until: z.string() }).nullable(),
  metrics: z.array(z.string()),
  dimensions: z.array(z.object({ name: z.string(), grain: z.string().optional() })),
});

export type ReportingResultMeta = z.infer<typeof ReportingResultMetaSchema>;
