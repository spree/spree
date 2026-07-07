import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

// Labels live in `en.json` under `admin.store.unit_systems.*` and
// `admin.store.weight_units.*`. Consumers translate at render time.
export type UnitSystem = 'metric' | 'imperial'
export const UNIT_SYSTEMS: readonly UnitSystem[] = ['metric', 'imperial']
export const WEIGHT_UNITS: Record<UnitSystem, readonly string[]> = {
  metric: ['kg', 'g'],
  imperial: ['lb', 'oz'],
}
const ALL_WEIGHT_UNITS = [...WEIGHT_UNITS.metric, ...WEIGHT_UNITS.imperial] as const

// Store-wide storefront posture. Unlike the channel field there is no blank
// "inherit" option — the store is the terminal fallback in the resolution
// chain, so it always holds a concrete value. Labels live in `en.json` under
// `admin.fields.store.storefront_access.options.*`.
export const STOREFRONT_ACCESS_LEVELS = ['public', 'prices_hidden', 'login_required'] as const

export const storeSettingsFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('store.name') }),
  preferred_admin_locale: z.string().nullable().optional(),
  preferred_timezone: z.string().min(1, { error: requiredMessage('store.preferred_timezone') }),
  preferred_unit_system: z.enum(['metric', 'imperial']),
  preferred_weight_unit: z.enum(ALL_WEIGHT_UNITS),
  preferred_storefront_access: z.enum(STOREFRONT_ACCESS_LEVELS),
  preferred_guest_checkout: z.boolean(),

  // Active Storage signed_id from a fresh direct upload. Frontend-only state.
  logo_signed_id: z.string().nullable().optional(),
  // Local blob URL for the just-picked file so the preview updates before save.
  logo_preview_url: z.string().nullable().optional(),
  // Tracks the user clicking "Remove logo" — collapses to `logo: null`.
  logo_cleared: z.boolean().optional(),
})

export type StoreSettingsFormValues = z.infer<typeof storeSettingsFormSchema>
