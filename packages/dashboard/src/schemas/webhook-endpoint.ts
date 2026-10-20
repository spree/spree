import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

export const webhookEndpointFormSchema = z.object({
  name: z.string().trim().optional().nullable(),
  url: z
    .string()
    .min(1, { error: requiredMessage('webhook_endpoint.url') })
    .url(),
  active: z.boolean(),
  // Empty array == subscribe to every event (the model treats `[]` and `['*']`
  // the same). The picker emits an empty array when nothing is selected.
  subscriptions: z.array(z.string().min(1)),
})

export type WebhookEndpointFormValues = z.infer<typeof webhookEndpointFormSchema>

export const DEFAULT_WEBHOOK_ENDPOINT_VALUES: WebhookEndpointFormValues = {
  name: '',
  url: '',
  active: true,
  subscriptions: [],
}
