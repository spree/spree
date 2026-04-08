// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const CustomFieldSchema = z.object({
  id: z.string(),
  label: z.string(),
  type: z.string(),
  key: z.string(),
  value: z.any(),
});

export type CustomField = z.infer<typeof CustomFieldSchema>;
