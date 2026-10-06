// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const OauthApplicationSchema = z.object({
  id: z.string(),
  name: z.string(),
  redirect_uri: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  client_id: z.string(),
  scopes: z.array(z.string()),
  last_authorized_at: z.string().nullable(),
  authorized_at: z.string().nullable(),
  authorized_by: z.string().nullable(),
});

export type OauthApplication = z.infer<typeof OauthApplicationSchema>;
