// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ResourceTypeDefinitionSchema = z.object({
  type: z.string(),
  label: z.string(),
  description: z.string().nullable(),
  schema: z.any(),
  superseded: z.boolean().optional(),
});

export type ResourceTypeDefinition = z.infer<typeof ResourceTypeDefinitionSchema>;
