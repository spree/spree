import { z } from 'zod/v4'
import type {
  PromotionActionFormDraft,
  PromotionRuleFormDraft,
} from '@/components/spree/promotion-editors/types'

export type PromotionKind = 'coupon_code' | 'automatic'
export type MatchPolicy = 'all' | 'any'

export const KIND_OPTIONS = [
  { value: 'coupon_code', label: 'Coupon code' },
  { value: 'automatic', label: 'Automatic (no code)' },
] as const satisfies ReadonlyArray<{ value: PromotionKind; label: string }>

export const MATCH_POLICY_OPTIONS = [
  { value: 'all', label: 'All rules must match' },
  { value: 'any', label: 'Any rule may match' },
] as const satisfies ReadonlyArray<{ value: MatchPolicy; label: string }>

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
    name: z.string().min(1, 'Name is required'),
    description: z.string(),
    kind: z.enum(['coupon_code', 'automatic']),
    code: z.string(),
    multi_codes: z.boolean(),
    number_of_codes: z.coerce.number().int().positive().optional(),
    code_prefix: z.string(),
    starts_at: z.string(),
    expires_at: z.string(),
    usage_limit: z.coerce.number().int().positive().optional(),
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
            message: 'Prefix is required for multi-code batches',
          })
        }
        if (!v.number_of_codes || v.number_of_codes < 1) {
          ctx.addIssue({
            code: 'custom',
            path: ['number_of_codes'],
            message: 'Pick how many codes to generate',
          })
        }
      } else {
        if (!v.code?.trim()) {
          ctx.addIssue({
            code: 'custom',
            path: ['code'],
            message: 'Code is required (or click Generate)',
          })
        }
      }
    }

    if (v.starts_at && v.expires_at && v.starts_at >= v.expires_at) {
      ctx.addIssue({
        code: 'custom',
        path: ['expires_at'],
        message: 'Expiry must be after the start date',
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
