// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ReportingMetricValueSchema = z.object({
  value: z.union([z.string(), z.number()]).nullable(),
  previous: z.union([z.string(), z.number()]).optional(),
  growth: z.string().nullable().optional(),
  display: z.string().optional(),
});

export type ReportingMetricValue = z.infer<typeof ReportingMetricValueSchema>;
