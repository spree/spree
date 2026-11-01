// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ActorSchema } from './Actor';
import { SessionSchema } from './Session';

export const AdminUserSchema = z.object({
  id: z.string(),
  email: z.string(),
  first_name: z.string().nullable(),
  last_name: z.string().nullable(),
  full_name: z.string().nullable(),
  selected_locale: z.string().nullable(),
  status: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  last_active_at: z.string().nullable(),
  sessions: z.array(SessionSchema).optional(),
  inviter: ActorSchema.nullable().optional(),
  avatar_url: z.string().nullable(),
  roles: z.array(z.object({ id: z.string(), name: z.string() })),
  stores: z.array(z.object({ id: z.string(), name: z.string(), code: z.string() })),
});

export type AdminUser = z.infer<typeof AdminUserSchema>;
