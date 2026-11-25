// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const TranslationCoverageSchema = z.object({
  resource_type: z.string(),
  default_locale: z.string(),
  locales: z.array(z.string()),
  field_count: z.number(),
  search_field: z.string().nullable(),
  coverage: z.array(z.object({ locale: z.string(), translated: z.number(), total: z.number(), coverage: z.number() })),
  records: z.array(z.object({ id: z.string(), label: z.string().nullable(), locales: z.record(z.string(), z.number()) })),
});

export type TranslationCoverage = z.infer<typeof TranslationCoverageSchema>;
