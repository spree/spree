import { attachmentImageParam, imageTripleDefaults } from '@spree/dashboard-core'
import { requiredMessage } from '@spree/dashboard-ui'
import type { ProfileUpdateParams } from '@spree/seller-sdk'
import { z } from 'zod/v4'

export const profileFormSchema = z.object({
  name: z
    .string()
    .trim()
    .min(1, { error: requiredMessage('name') }),
  contact_email: z.email().or(z.literal('')).optional(),
  billing_email: z.email().or(z.literal('')).optional(),
  about: z.string().optional(),
  logo_signed_id: z.string().nullable(),
  logo_preview_url: z.string().nullable(),
  logo_cleared: z.boolean(),
  square_logo_signed_id: z.string().nullable(),
  square_logo_preview_url: z.string().nullable(),
  square_logo_cleared: z.boolean(),
  cover_photo_signed_id: z.string().nullable(),
  cover_photo_preview_url: z.string().nullable(),
  cover_photo_cleared: z.boolean(),
})

export type ProfileFormValues = z.infer<typeof profileFormSchema>

export const PROFILE_DEFAULTS: ProfileFormValues = {
  name: '',
  contact_email: '',
  billing_email: '',
  about: '',
  ...imageTripleDefaults('logo'),
  ...imageTripleDefaults('square_logo'),
  ...imageTripleDefaults('cover_photo'),
}

export function profileValuesToParams(
  values: ProfileFormValues,
): Pick<ProfileUpdateParams, 'name' | 'contact_email' | 'billing_email' | 'about'> {
  return {
    name: values.name,
    contact_email: values.contact_email || null,
    billing_email: values.billing_email || null,
    about: values.about || null,
  }
}

export function profileImageParams(
  values: ProfileFormValues,
): Partial<Pick<ProfileUpdateParams, 'logo' | 'square_logo' | 'cover_photo'>> {
  return {
    ...attachmentImageParam('logo', values.logo_signed_id, values.logo_cleared),
    ...attachmentImageParam(
      'square_logo',
      values.square_logo_signed_id,
      values.square_logo_cleared,
    ),
    ...attachmentImageParam(
      'cover_photo',
      values.cover_photo_signed_id,
      values.cover_photo_cleared,
    ),
  }
}
