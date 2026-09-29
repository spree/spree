// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const RoleSchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  permissions: z.array(z.string()),
  mutable: z.boolean(),
  users_count: z.number(),
});

export type Role = z.infer<typeof RoleSchema>;
