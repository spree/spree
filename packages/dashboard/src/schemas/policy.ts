import type { Policy, PolicyCreateParams } from '@spree/admin-sdk'
import { z } from 'zod/v4'

/**
 * A policy document. `body` carries HTML — the editor writes markup and the
 * server sanitizes it on save — so the form is seeded from `body_html`, never
 * from the plain-text `body` the API also returns.
 */
export const policyFormSchema = z.object({
  name: z.string().min(1),
  slug: z.string(),
  body: z.string(),
})

export type PolicyFormValues = z.infer<typeof policyFormSchema>

export const POLICY_DEFAULTS: PolicyFormValues = {
  name: '',
  slug: '',
  body: '',
}

export function policyToFormValues(policy: Policy): PolicyFormValues {
  return {
    name: policy.name,
    slug: policy.slug,
    body: policy.body_html ?? '',
  }
}

export function policyValuesToParams(values: PolicyFormValues): PolicyCreateParams {
  return {
    name: values.name,
    // Left out when blank so the server derives it from the name, rather than
    // being asked to store an empty slug.
    ...(values.slug ? { slug: values.slug } : {}),
    body: values.body,
  }
}
