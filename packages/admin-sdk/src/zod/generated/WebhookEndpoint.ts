// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const WebhookEndpointSchema = z.object({
  id: z.string(),
  name: z.string().nullable(),
  url: z.string(),
  active: z.boolean(),
  subscriptions: z.array(z.string()),
  disabled_reason: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  disabled_at: z.string().nullable(),
  secret_key: z.string().nullable(),
  last_delivery_at: z.string().nullable(),
  recent_delivery_count: z.number(),
  recent_failure_count: z.number(),
  total_delivery_count: z.number(),
  successful_delivery_count: z.number(),
  failed_delivery_count: z.number(),
});

export type WebhookEndpoint = z.infer<typeof WebhookEndpointSchema>;
