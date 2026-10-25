// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const OauthConsentRequestSchema = z.object({
  client_name: z.string(),
  scopes: z.array(z.string()),
  grantable_scopes: z.array(z.string()),
  resource: z.string().nullable(),
  redirect_uri: z.string(),
});

export type OauthConsentRequest = z.infer<typeof OauthConsentRequestSchema>;
