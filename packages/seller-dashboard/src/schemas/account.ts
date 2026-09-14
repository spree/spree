import type { AccountUpdateParams, MeResponse } from '@spree/seller-sdk'
import { z } from 'zod/v4'

// The signed-in person's own account (PATCH /me) — not the seller business
// they act for, which is `pages/profile.tsx`. Every field is optional: the
// panel asks for a name but does not require one.
//
// The panel's languages are NOT listed here. They are derived at render time
// from the locale bundles the panel ships (see `getAvailableUiLocales`), which
// is what it can actually display — the API knows nothing about that.
//
// The avatar is a small state machine: untouched (omit on save), uploaded
// (send the signed id), or cleared (send null to purge). `avatar_signed_id`
// carries a freshly direct-uploaded blob, `avatar_preview_url` a transient
// object URL for the just-picked file, and `avatar_cleared` flags a removal of
// the persisted photo.
export const accountFormSchema = z.object({
  first_name: z.string().nullable().optional(),
  last_name: z.string().nullable().optional(),
  selected_locale: z.string().nullable().optional(),
  avatar_signed_id: z.string().nullable(),
  avatar_preview_url: z.string().nullable(),
  avatar_cleared: z.boolean(),
})

export type AccountFormValues = z.infer<typeof accountFormSchema>

/** Hydrate the form from the current account (the `/me` response). */
export function accountToForm(me: MeResponse, fallbackLocale: string): AccountFormValues {
  return {
    first_name: me.user.first_name ?? '',
    last_name: me.user.last_name ?? '',
    selected_locale: me.user.selected_locale || fallbackLocale,
    avatar_signed_id: null,
    avatar_preview_url: null,
    avatar_cleared: false,
  }
}

/** Map the form to the PATCH /me params (drops the frontend-only fields). */
export function accountToParams(values: AccountFormValues): AccountUpdateParams {
  return {
    // Sent as typed, empty string included: the backend normalizes a blank
    // name to null, so an emptied field is how a person removes a name they
    // once gave. Coercing blank to `undefined` would drop the field from the
    // PATCH, leaving the old name in place while the dialog reported success.
    first_name: values.first_name ?? undefined,
    last_name: values.last_name ?? undefined,
    // `||` rather than `??`, unlike the names above: an empty locale means no
    // language was chosen, never "clear the one I have".
    selected_locale: values.selected_locale || undefined,
    ...avatarParam(values.avatar_signed_id, values.avatar_cleared),
  }
}

// Three states: a fresh upload sends the signed id, an explicit clear sends
// null (which purges the attachment), and an untouched field is omitted.
function avatarParam(signedId: string | null, cleared: boolean) {
  if (signedId) return { avatar: signedId }
  if (cleared) return { avatar: null }
  return {}
}
