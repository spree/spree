// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const OauthRedirectSchema = z.object({
  redirect_uri: z.string(),
});

export type OauthRedirect = z.infer<typeof OauthRedirectSchema>;
