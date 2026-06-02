import type { ChannelCreateParams, ChannelUpdateParams } from '@spree/admin-sdk'
import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

export const channelFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('name') }),
  code: z
    .string()
    .min(1, { error: requiredMessage('code') })
    .regex(/^[a-z0-9_-]+$/i, {
      error: 'Lowercase letters, numbers, hyphens, underscores only',
    }),
  active: z.boolean(),
})

export type ChannelFormValues = z.infer<typeof channelFormSchema>

export const CHANNEL_DEFAULTS: ChannelFormValues = {
  name: '',
  code: '',
  active: true,
}

export function channelValuesToParams(
  v: ChannelFormValues,
): ChannelCreateParams & ChannelUpdateParams {
  return {
    name: v.name,
    code: v.code,
    active: v.active,
  }
}
