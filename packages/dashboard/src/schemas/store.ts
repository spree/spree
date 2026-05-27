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

export const ADMIN_LOCALE_OPTIONS: Array<{ value: string; label: string }> = [
  { value: 'en', label: 'English' },
  { value: 'fr', label: 'Français' },
  { value: 'de', label: 'Deutsch' },
  { value: 'es', label: 'Español' },
  { value: 'it', label: 'Italiano' },
  { value: 'pt-BR', label: 'Português (Brasil)' },
  { value: 'pl', label: 'Polski' },
  { value: 'nl', label: 'Nederlands' },
  { value: 'ja', label: '日本語' },
  { value: 'zh-CN', label: '中文 (简体)' },
]
