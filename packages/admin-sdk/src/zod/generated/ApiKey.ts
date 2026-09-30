// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ApiKeySchema = z.object({
  id: z.string(),
  name: z.string(),
  key_type: z.string(),
  token_prefix: z.string().nullable(),
  scopes: z.array(z.string()),
  created_at: z.string(),
  updated_at: z.string(),
  revoked_at: z.string().nullable(),
  last_used_at: z.string().nullable(),
  channel_id: z.string().nullable(),
  plaintext_token: z.string().nullable(),
  created_by_email: z.string().nullable(),
  created_by_type: z.string().nullable(),
  created_by_label: z.string().nullable(),
});

export type ApiKey = z.infer<typeof ApiKeySchema>;
