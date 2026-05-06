import { z } from 'zod/v4'

export const storeSettingsFormSchema = z.object({
  name: z.string().min(1, 'Name is required'),
  preferred_admin_locale: z.string().nullable().optional(),
  preferred_timezone: z.string().min(1, 'Timezone is required'),
  preferred_unit_system: z.enum(['metric', 'imperial']),
  preferred_weight_unit: z.string().min(1, 'Weight unit is required'),
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

export const UNIT_SYSTEM_OPTIONS: Array<{ value: 'metric' | 'imperial'; label: string }> = [
  { value: 'metric', label: 'Metric' },
  { value: 'imperial', label: 'Imperial' },
]

export const WEIGHT_UNIT_OPTIONS: Record<
  'metric' | 'imperial',
  Array<{ value: string; label: string }>
> = {
  metric: [
    { value: 'kg', label: 'Kilogram (kg)' },
    { value: 'g', label: 'Gram (g)' },
  ],
  imperial: [
    { value: 'lb', label: 'Pound (lb)' },
    { value: 'oz', label: 'Ounce (oz)' },
  ],
}
