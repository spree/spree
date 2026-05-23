import type {
  GiftCardBatchCreateParams,
  GiftCardCreateParams,
  GiftCardUpdateParams,
} from '@spree/admin-sdk'
import { z } from 'zod/v4'
import { blankToNull, blankToUndefined } from '@/lib/form-mappers'
import { i18n } from '@/lib/i18n'

// Mirrors `Spree::Config[:gift_card_batch_limit]`. Hardcoded for now; if the
// merchant overrides it we'll surface it via a store-settings endpoint later.
export const BATCH_LIMIT = 50_000

// Zod accepts a message function for lazy evaluation — important so the i18n
// catalog has had a chance to initialize and so locale changes pick up.
const amountPositive = () => i18n.t('admin.pages.promotions.gift_cards.validation.amount_positive')
const prefixRequired = () => i18n.t('admin.pages.promotions.gift_cards.validation.prefix_required')
const currencyRequired = () =>
  i18n.t('admin.pages.promotions.gift_cards.validation.currency_required')

export const giftCardCreateFormSchema = z
  .object({
    // When `quantity === 1` this is the optional caller-supplied code.
    // When `quantity > 1` it becomes the required batch `prefix`.
    code: z.string().optional(),
    amount: z.coerce.number().positive({ error: amountPositive }),
    currency: z.string().min(1, { error: currencyRequired }),
    expires_at: z.string().optional(),
    customer_id: z.string().optional(),
    quantity: z.coerce.number().int().min(1).max(BATCH_LIMIT),
  })
  .superRefine((values, ctx) => {
    if (values.quantity > 1 && !values.code?.trim()) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['code'],
        message: prefixRequired(),
      })
    }
  })

export type GiftCardCreateFormValues = z.infer<typeof giftCardCreateFormSchema>

export const giftCardEditFormSchema = z.object({
  code: z.string().optional(),
  amount: z.coerce.number().positive({ error: amountPositive }),
  currency: z.string().min(1, { error: currencyRequired }),
  expires_at: z.string().optional(),
  customer_id: z.string().optional(),
})

export type GiftCardEditFormValues = z.infer<typeof giftCardEditFormSchema>

export function giftCardEditValuesToParams(v: GiftCardEditFormValues): GiftCardUpdateParams {
  return {
    amount: v.amount,
    expires_at: v.expires_at || null,
    user_id: blankToNull(v.customer_id),
  }
}

export function giftCardSingleValuesToParams(v: GiftCardCreateFormValues): GiftCardCreateParams {
  return {
    code: blankToUndefined(v.code),
    amount: v.amount,
    currency: v.currency,
    expires_at: v.expires_at || null,
    user_id: blankToNull(v.customer_id),
  }
}

export function giftCardBatchValuesToParams(
  v: GiftCardCreateFormValues,
): GiftCardBatchCreateParams {
  // `code` carries the prefix in batch mode; required, validated above.
  return {
    prefix: v.code ?? '',
    amount: v.amount,
    currency: v.currency,
    codes_count: v.quantity,
    expires_at: v.expires_at || null,
  }
}
