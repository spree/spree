// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ReportingDimensionValueSchema } from './ReportingDimensionValue';
import { ReportingMetricValueSchema } from './ReportingMetricValue';

export const ReportingRowSchema = z.object({
  dimensions: z.record(z.string(), z.union([z.string(), ReportingDimensionValueSchema]).nullable()),
  metrics: z.record(z.string(), ReportingMetricValueSchema),
});

export type ReportingRow = z.infer<typeof ReportingRowSchema>;
