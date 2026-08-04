import { MonitorIcon, MoonStarIcon, SunIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { cn } from '../lib/utils'
import { useTheme } from './theme-provider'

const OPTIONS = [
  { value: 'system', icon: MonitorIcon, labelKey: 'admin.components.theme_toggle.system' },
  { value: 'light', icon: SunIcon, labelKey: 'admin.components.theme_toggle.light' },
  { value: 'dark', icon: MoonStarIcon, labelKey: 'admin.components.theme_toggle.dark' },
] as const

/**
 * Theme picker rendered inside the user dropdown's Preferences section as a
 * compact segmented control (System / Light / Dark). System follows
 * `prefers-color-scheme`. The buttons are plain (not menu items) so activating
 * one switches the theme without closing the dropdown.
 */
export function ThemeMenuItems() {
  const { mode, setMode } = useTheme()
  const { t } = useTranslation()

  return (
    <div className="flex items-center justify-between gap-2 px-2.5 py-1.5">
      <span className="text-sm text-foreground">{t('admin.components.theme_toggle.label')}</span>
      <div className="flex items-center gap-0.5 rounded-lg border border-border bg-muted/40 p-0.5">
        {OPTIONS.map(({ value, icon: Icon, labelKey }) => {
          const active = mode === value
          return (
            <button
              key={value}
              type="button"
              aria-pressed={active}
              aria-label={t(labelKey)}
              title={t(labelKey)}
              onClick={() => setMode(value)}
              className={cn(
                'flex size-7 items-center justify-center rounded-md text-muted-foreground transition-colors hover:text-foreground',
                active && 'bg-background text-foreground shadow-sm',
              )}
            >
              <Icon className="size-4" />
            </button>
          )
        })}
      </div>
    </div>
  )
}
