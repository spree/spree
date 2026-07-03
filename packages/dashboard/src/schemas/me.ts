import type { MeResponse, MeUpdateParams } from '@spree/admin-sdk'
import { z } from 'zod/v4'

// Profile form for the signed-in admin (PATCH /me). All fields optional —
// mirrors the Rails admin profile, which doesn't require first/last name.
// The admin-UI language options are NOT listed here: they're derived at render
// time from the dashboard's shipped locale bundles (see getAvailableUiLocales),
// which is what the SPA can actually display — not a backend list.
//
// The avatar is a small state machine: untouched (omit on save), uploaded
// (send signed_id), or cleared (send null to purge). `avatar_signed_id` carries
// a freshly direct-uploaded blob; `avatar_preview_url` is a transient object URL
// for the just-picked file; `avatar_cleared` flags a removal of the persisted
// photo.
export const meFormSchema = z.object({
  first_name: z.string().nullable().optional(),
  last_name: z.string().nullable().optional(),
  selected_locale: z.string().nullable().optional(),
  avatar_signed_id: z.string().nullable(),
  avatar_preview_url: z.string().nullable(),
  avatar_cleared: z.boolean(),
})

export type MeFormValues = z.infer<typeof meFormSchema>

/** Hydrate the form from the current admin (PATCH /me response). */
export function meToForm(me: MeResponse, fallbackLocale: string): MeFormValues {
  return {
    first_name: me.user.first_name ?? '',
    last_name: me.user.last_name ?? '',
    selected_locale: me.user.selected_locale || fallbackLocale,
    avatar_signed_id: null,
    avatar_preview_url: null,
    avatar_cleared: false,
  }
}

/** Map the form to the PATCH /me params (drops frontend-only fields). */
export function meToParams(values: MeFormValues): MeUpdateParams {
  return {
    first_name: values.first_name || undefined,
    last_name: values.last_name || undefined,
    selected_locale: values.selected_locale || undefined,
    ...avatarParam(values.avatar_signed_id, values.avatar_cleared),
  }
}

// Three-state mapping: a fresh upload sends the signed_id, an explicit clear
// sends null (purges the attachment), and an untouched field is omitted.
function avatarParam(signedId: string | null, cleared: boolean) {
  if (signedId) return { avatar: signedId }
  if (cleared) return { avatar: null }
  return {}
}
