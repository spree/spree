// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const TagSchema = z.object({
  name: z.string(),
});

export type Tag = z.infer<typeof TagSchema>;
