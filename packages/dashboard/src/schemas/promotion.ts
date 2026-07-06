import { emptyToUndefined, i18n } from '@spree/dashboard-core'
import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'
import type {
  PromotionActionFormDraft,
  PromotionRuleFormDraft,
} from '../components/spree/promotion-editors/types'

export type PromotionKind = 'coupon_code' | 'automatic'
export type MatchPolicy = 'all' | 'any'

// Labels live in `en.json` under `admin.promotions.kinds.*` and
// `admin.promotions.match_policies.*`. Consumers translate at render time.
export const PROMOTION_KINDS = [
  'coupon_code',
  'automatic',
] as const satisfies ReadonlyArray<PromotionKind>
export const MATCH_POLICIES = ['all', 'any'] as const satisfies ReadonlyArray<MatchPolicy>

/**
 * Promotion form schema.
 *
 * Most field-level rules (presence of name, currency, etc.) are validated
 * server-side and surfaced via `mapSpreeErrorsToForm`. The client-side
 * `superRefine` block here only catches **cross-field** rules where the UI
 * can react before the server round-trip:
 *
 *   - `code` is required for single-code coupon promotions
 *   - `number_of_codes` + `code_prefix` are required for multi-code batches
 *   - `expires_at` must be after `starts_at` when both are set
 *
 * The shape of `rules` and `actions` is preserved through `z.array(z.any())`
 * because they're complex discriminated drafts owned by their own editor
 * components (see `promotion-editors/types.ts`). Validating them here would
 * duplicate that logic; the server is the source of truth for rule/action
 * payload validity.
 */
export const promotionFormSchema = z
  .object({
    name: z.string().min(1, { error: requiredMessage('name') }),
    description: z.string(),
    kind: z.enum(['coupon_code', 'automatic']),
    code: z.string(),
    multi_codes: z.boolean(),
    number_of_codes: z.preprocess(emptyToUndefined, z.coerce.number().int().positive().optional()),
    code_prefix: z.string(),
    starts_at: z.string(),
    expires_at: z.string(),
    usage_limit: z.preprocess(emptyToUndefined, z.coerce.number().int().positive().optional()),
    match_policy: z.enum(['all', 'any']),
    // Rule/action drafts are owned by the editor components; we accept whatever
    // shape they emit and let the server's rule/action serializers validate.
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    rules: z.array(z.any() as z.ZodType<PromotionRuleFormDraft>),
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    actions: z.array(z.any() as z.ZodType<PromotionActionFormDraft>),
  })
  .superRefine((v, ctx) => {
    if (v.kind === 'coupon_code') {
      if (v.multi_codes) {
        if (!v.code_prefix?.trim()) {
          ctx.addIssue({
            code: 'custom',
            path: ['code_prefix'],
            message: i18n.t('admin.promotions.validation.prefix_required'),
          })
        }
        if (!v.number_of_codes || v.number_of_codes < 1) {
          ctx.addIssue({
            code: 'custom',
            path: ['number_of_codes'],
            message: i18n.t('admin.promotions.validation.number_of_codes_required'),
          })
        }
      } else {
        if (!v.code?.trim()) {
          ctx.addIssue({
            code: 'custom',
            path: ['code'],
            message: i18n.t('admin.promotions.validation.code_required'),
          })
        }
      }
    }

    if (v.starts_at && v.expires_at && v.starts_at >= v.expires_at) {
      ctx.addIssue({
        code: 'custom',
        path: ['expires_at'],
        message: i18n.t('admin.promotions.validation.expiry_after_start'),
      })
    }
  })

export type PromotionFormValues = z.infer<typeof promotionFormSchema>

export const PROMOTION_DEFAULTS: PromotionFormValues = {
  name: '',
  description: '',
  kind: 'coupon_code',
  code: '',
  multi_codes: false,
  number_of_codes: undefined,
  code_prefix: '',
  starts_at: '',
  expires_at: '',
  usage_limit: undefined,
  match_policy: 'all',
  rules: [],
  actions: [],
}
