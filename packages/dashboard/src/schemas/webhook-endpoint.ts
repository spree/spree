import {
  WEBHOOK_EVENT_PATTERN,
  WEBHOOK_SUBSCRIPTION_MAX_LENGTH,
  WEBHOOK_SUBSCRIPTIONS_MAX,
} from '@spree/core'
import { i18n } from '@spree/dashboard-core'
import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

const invalidSubscription = () => i18n.t('admin.fields.webhook_endpoint.subscriptions.invalid')

export const webhookEndpointFormSchema = z.object({
  name: z.string().trim().optional().nullable(),
  url: z
    .string()
    .min(1, { error: requiredMessage('webhook_endpoint.url') })
    .url(),
  active: z.boolean(),
  // Empty array == subscribe to every event (the model treats `[]` and `['*']`
  // the same). The picker emits an empty array when nothing is selected.
  subscriptions: z
    .array(
      z
        .string()
        .min(1, { error: invalidSubscription })
        .max(WEBHOOK_SUBSCRIPTION_MAX_LENGTH, { error: invalidSubscription })
        .regex(WEBHOOK_EVENT_PATTERN, { error: invalidSubscription }),
    )
    .max(WEBHOOK_SUBSCRIPTIONS_MAX, {
      error: () =>
        i18n.t('admin.fields.webhook_endpoint.subscriptions.too_many', {
          count: WEBHOOK_SUBSCRIPTIONS_MAX,
        }),
    }),
})

export type WebhookEndpointFormValues = z.infer<typeof webhookEndpointFormSchema>

export const DEFAULT_WEBHOOK_ENDPOINT_VALUES: WebhookEndpointFormValues = {
  name: '',
  url: '',
  active: true,
  subscriptions: [],
}
