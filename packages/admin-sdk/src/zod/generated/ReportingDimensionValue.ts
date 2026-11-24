// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ReportingDimensionValueSchema = z.object({
  id: z.string().nullable(),
  label: z.string(),
  meta: z.record(z.string(), z.unknown()),
});

export type ReportingDimensionValue = z.infer<typeof ReportingDimensionValueSchema>;
