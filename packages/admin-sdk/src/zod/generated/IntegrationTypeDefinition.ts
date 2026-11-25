// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const IntegrationTypeDefinitionSchema = z.object({
  type: z.string(),
  name: z.string(),
  group: z.string().nullable(),
  description: z.string().nullable(),
  logo_url: z.string().nullable(),
  docs_url: z.string().nullable(),
  schema: z.any(),
});

export type IntegrationTypeDefinition = z.infer<typeof IntegrationTypeDefinitionSchema>;
