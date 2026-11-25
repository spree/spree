// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const IntegrationConnectionResultSchema = z.object({
  connected: z.boolean(),
  error_message: z.string().nullable(),
});

export type IntegrationConnectionResult = z.infer<typeof IntegrationConnectionResultSchema>;
