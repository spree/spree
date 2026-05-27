import { z } from 'zod/v4'
import { i18n } from '@/lib/i18n'

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

/** Existing invitee confirming with their current password. */
export const acceptInvitationSignInFormSchema = z.object({
  password: z.string().min(1, { error: passwordRequired }),
})
export type AcceptInvitationSignInFormValues = z.infer<typeof acceptInvitationSignInFormSchema>

/** New invitee creating an account inline — mirrors the server's `AdminUser` validations. */
export const acceptInvitationSignUpFormSchema = z
  .object({
    first_name: z.string().min(1, { error: firstNameRequired }),
    last_name: z.string().min(1, { error: lastNameRequired }),
    password: z.string().min(8, { error: passwordMinLength }),
    password_confirmation: z.string(),
  })
  .refine((data) => data.password === data.password_confirmation, {
    error: passwordsDontMatch,
    path: ['password_confirmation'],
  })
export type AcceptInvitationSignUpFormValues = z.infer<typeof acceptInvitationSignUpFormSchema>
