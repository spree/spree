// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const WebhookEventSchema = z.object({
  name: z.string(),
  group: z.string(),
  credential_permission: z.string().nullable(),
  credential: z.boolean(),
  deprecated: z.boolean(),
  replaced_by: z.string().nullable(),
});

export type WebhookEvent = z.infer<typeof WebhookEventSchema>;
