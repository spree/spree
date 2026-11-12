// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const IntegrationSchema = z.object({
  id: z.string(),
  name: z.string(),
  active: z.boolean(),
  created_at: z.string(),
  updated_at: z.string(),
  type: z.string(),
  group: z.string().nullable(),
  preferences: z.record(z.string(), z.unknown()),
});

export type Integration = z.infer<typeof IntegrationSchema>;
