import type { ProfileUpdateParams } from '@spree/seller-sdk'
import { z } from 'zod/v4'

export const profileFormSchema = z.object({
  name: z.string().trim().min(1),
  contact_email: z.string(),
  billing_email: z.string(),
  about: z.string(),
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
  logo_signed_id: null,
  logo_preview_url: null,
  logo_cleared: false,
  square_logo_signed_id: null,
  square_logo_preview_url: null,
  square_logo_cleared: false,
  cover_photo_signed_id: null,
  cover_photo_preview_url: null,
  cover_photo_cleared: false,
}

export function profileValuesToParams(values: ProfileFormValues): ProfileUpdateParams {
  return {
    name: values.name,
    contact_email: values.contact_email || null,
    billing_email: values.billing_email || null,
    about: values.about || null,
    ...profileImageParams(values),
  }
}

export function profileImageParams(
  values: ProfileFormValues,
): Partial<Pick<ProfileUpdateParams, 'logo' | 'square_logo' | 'cover_photo'>> {
  return {
    ...imageParam('logo', values.logo_signed_id, values.logo_cleared),
    ...imageParam('square_logo', values.square_logo_signed_id, values.square_logo_cleared),
    ...imageParam('cover_photo', values.cover_photo_signed_id, values.cover_photo_cleared),
  }
}

function imageParam(
  key: 'logo' | 'square_logo' | 'cover_photo',
  signedId: string | null,
  cleared: boolean,
): Partial<Record<'logo' | 'square_logo' | 'cover_photo', string | null>> {
  if (signedId) return { [key]: signedId }
  if (cleared) return { [key]: null }
  return {}
}
