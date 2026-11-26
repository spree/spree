// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const EmailApiKeySchema = z.object({
  id: z.unknown(),
  name: z.unknown(),
  token_prefix: z.unknown(),
  scopes: z.unknown(),
  created_by_ip_address: z.unknown(),
  created_at: z.unknown(),
  created_by_name: z.unknown(),
});

export type EmailApiKey = z.infer<typeof EmailApiKeySchema>;
