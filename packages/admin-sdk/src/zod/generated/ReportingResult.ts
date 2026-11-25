// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ReportingMetricValueSchema } from './ReportingMetricValue';
import { ReportingResultMetaSchema } from './ReportingResultMeta';
import { ReportingRowSchema } from './ReportingRow';

export const ReportingResultSchema = z.object({
  meta: ReportingResultMetaSchema,
  totals: z.record(z.string(), ReportingMetricValueSchema),
  rows: z.array(ReportingRowSchema),
});

export type ReportingResult = z.infer<typeof ReportingResultSchema>;
