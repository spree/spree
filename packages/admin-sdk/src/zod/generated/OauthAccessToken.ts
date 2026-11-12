// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AdminUserSchema } from './AdminUser';

export const OauthAccessTokenSchema = z.object({
  id: z.string(),
  created_at: z.string(),
  owner_id: z.string().nullable(),
  owner_type: z.string().nullable(),
  owner: AdminUserSchema.optional(),
  scopes: z.array(z.string()),
  expired: z.boolean(),
});

export type OauthAccessToken = z.infer<typeof OauthAccessTokenSchema>;
