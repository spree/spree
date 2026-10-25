// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const OauthProtectedResourceSchema = z.object({
  resource: z.string(),
  authorization_servers: z.array(z.string()),
  scopes_supported: z.array(z.string()),
  bearer_methods_supported: z.array(z.string()),
  resource_documentation: z.string(),
});

export type OauthProtectedResource = z.infer<typeof OauthProtectedResourceSchema>;
