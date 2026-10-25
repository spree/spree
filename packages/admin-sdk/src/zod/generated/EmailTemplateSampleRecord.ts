// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const EmailTemplateSampleRecordSchema = z.object({
  id: z.string(),
  label: z.string(),
  created_at: z.string(),
});

export type EmailTemplateSampleRecord = z.infer<typeof EmailTemplateSampleRecordSchema>;
