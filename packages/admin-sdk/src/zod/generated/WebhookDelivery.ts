// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const WebhookDeliverySchema = z.object({
  id: z.string(),
  event_name: z.string(),
  event_id: z.string().nullable(),
  response_code: z.number().nullable(),
  execution_time: z.number().nullable(),
  error_type: z.string().nullable(),
  request_errors: z.string().nullable(),
  response_body: z.string().nullable(),
  success: z.boolean().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  delivered_at: z.string().nullable(),
  payload: z.record(z.string(), z.unknown()).nullable(),
  webhook_endpoint_id: z.string(),
  webhook_endpoint_url: z.string(),
});

export type WebhookDelivery = z.infer<typeof WebhookDeliverySchema>;
