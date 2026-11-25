// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const TranslatableResourceSchema = z.object({
  resource_type: z.string(),
  fields: z.array(z.object({ key: z.string(), type: z.string() })),
  readable: z.boolean(),
});

export type TranslatableResource = z.infer<typeof TranslatableResourceSchema>;
