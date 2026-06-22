import { CheckIcon, MonitorIcon, MoonIcon, SunIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { DropdownMenuItem, DropdownMenuLabel, DropdownMenuSeparator } from '../ui/dropdown-menu'
import { useTheme } from './theme-provider'

/**
 * Theme picker rendered inside the user dropdown menu. Three-way (Light / Dark
 * / System) — System follows `prefers-color-scheme`.
 */
export function ThemeMenuItems() {
  const { mode, setMode } = useTheme()
  const { t } = useTranslation()

  const items = [
    { value: 'light', label: t('admin.components.theme_toggle.light'), icon: SunIcon },
    { value: 'dark', label: t('admin.components.theme_toggle.dark'), icon: MoonIcon },
    { value: 'system', label: t('admin.components.theme_toggle.system'), icon: MonitorIcon },
  ] as const

  return (
    <>
      <DropdownMenuLabel className="text-xs">
        {t('admin.components.theme_toggle.label')}
      </DropdownMenuLabel>
      {items.map(({ value, label, icon: Icon }) => (
        <DropdownMenuItem key={value} closeOnClick={false} onClick={() => setMode(value)}>
          <Icon className="size-4" />
          {label}
          {mode === value && <CheckIcon className="ml-auto size-3.5" />}
        </DropdownMenuItem>
      ))}
      <DropdownMenuSeparator />
    </>
  )
}
