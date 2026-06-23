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

export const storeSettingsFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('store.name') }),
  preferred_admin_locale: z.string().nullable().optional(),
  preferred_timezone: z.string().min(1, { error: requiredMessage('store.preferred_timezone') }),
  preferred_unit_system: z.enum(['metric', 'imperial']),
  preferred_weight_unit: z.enum(ALL_WEIGHT_UNITS),
})

export type StoreSettingsFormValues = z.infer<typeof storeSettingsFormSchema>
