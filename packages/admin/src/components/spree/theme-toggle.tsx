import { CheckIcon, MonitorIcon, MoonIcon, SunIcon } from 'lucide-react'
import {
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
} from '@/components/ui/dropdown-menu'
import { useTheme } from '@/providers/theme-provider'

/**
 * Theme picker rendered inside the user dropdown menu. Three-way (Light / Dark
 * / System) — System follows `prefers-color-scheme`.
 */
export function ThemeMenuItems() {
  const { mode, setMode } = useTheme()

  const items = [
    { value: 'light', label: 'Light', icon: SunIcon },
    { value: 'dark', label: 'Dark', icon: MoonIcon },
    { value: 'system', label: 'System', icon: MonitorIcon },
  ] as const

  return (
    <>
      <DropdownMenuLabel className="text-xs">Theme</DropdownMenuLabel>
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
