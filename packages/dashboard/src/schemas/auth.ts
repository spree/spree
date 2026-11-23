import {
  countryCodeSchema,
  currencyCodeSchema,
  i18n,
  localeCodeSchema,
} from '@spree/dashboard-core'
import { z } from 'zod/v4'

// Lazy message factories — Zod v4 accepts `{ error: () => string }` as an
// error map, which it invokes per validation. Module-scope `i18n.t(...)`
// would lock the English string in at import time, breaking locale switches
// once we ship a second translation.
const passwordRequired = () => i18n.t('admin.validation.password_required')
const firstNameRequired = () => i18n.t('admin.validation.first_name_required')
const lastNameRequired = () => i18n.t('admin.validation.last_name_required')
const passwordsDontMatch = () => i18n.t('admin.validation.passwords_dont_match')
const passwordMinLength = () =>
  i18n.t('admin.validation.min_length', {
    field: i18n.t('admin.fields.password.label'),
    count: 8,
  })

/** Login form — server validates password strength; client only checks presence. */
export const loginFormSchema = z.object({
  email: z.email(),
  password: z.string().min(1, { error: passwordRequired }),
})
export type LoginFormValues = z.infer<typeof loginFormSchema>

/** Forgot-password request — just the email; the server never reveals whether it matched. */
export const forgotPasswordFormSchema = z.object({
  email: z.email(),
})
export type ForgotPasswordFormValues = z.infer<typeof forgotPasswordFormSchema>

/** Choosing a new password from a reset link — mirrors the server's strength rule. */
export const resetPasswordFormSchema = z
  .object({
    password: z.string().min(8, { error: passwordMinLength }),
    password_confirmation: z.string(),
  })
  .refine((data) => data.password === data.password_confirmation, {
    error: passwordsDontMatch,
    path: ['password_confirmation'],
  })
export type ResetPasswordFormValues = z.infer<typeof resetPasswordFormSchema>

/** First-run setup — the first admin account plus the store's name. */
export const setupFormSchema = z
  .object({
    email: z.email(),
    first_name: z.string().min(1, { error: firstNameRequired }),
    last_name: z.string().min(1, { error: lastNameRequired }),
    password: z.string().min(8, { error: passwordMinLength }),
    password_confirmation: z.string(),
    store_name: z.string().min(1, { error: () => i18n.t('admin.validation.store_name_required') }),
    country_code: countryCodeSchema,
    locale: localeCodeSchema,
    currency: currencyCodeSchema,
    sample_data: z.boolean(),
  })
  .refine((data) => data.password === data.password_confirmation, {
    error: passwordsDontMatch,
    path: ['password_confirmation'],
  })
export type SetupFormValues = z.infer<typeof setupFormSchema>
