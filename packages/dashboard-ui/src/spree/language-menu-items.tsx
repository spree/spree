import { CheckIcon, LanguagesIcon } from 'lucide-react'
import {
  DropdownMenuItem,
  DropdownMenuSub,
  DropdownMenuSubContent,
  DropdownMenuSubTrigger,
} from '../ui/dropdown-menu'

interface LanguageMenuItemsProps {
  /** Translated "Language" label for the submenu trigger (passed by the app). */
  label: string
  /** Admin UI languages available to switch to ({ code, name } pairs). */
  locales: ReadonlyArray<{ code: string; name: string }>
  /** Currently active language code. */
  value: string
  onSelect: (code: string) => void
}

/**
 * Admin UI language picker rendered inside the user dropdown menu as a nested
 * submenu (a single "Language ▸" row that expands to the list), so the menu
 * stays compact no matter how many languages are installed.
 *
 * Headless: the label, locale list, and change handler are passed in, so this
 * component imports no i18n/data runtime. Renders nothing when fewer than two
 * languages are installed: there's nothing to choose.
 */
export function LanguageMenuItems({ label, locales, value, onSelect }: LanguageMenuItemsProps) {
  if (locales.length < 2) return null

  const current = locales.find((l) => l.code === value)

  return (
    <DropdownMenuSub>
      <DropdownMenuSubTrigger>
        <LanguagesIcon className="size-4" />
        {label}
        {current && <span className="ml-auto text-xs text-muted-foreground">{current.name}</span>}
      </DropdownMenuSubTrigger>
      <DropdownMenuSubContent>
        {locales.map((locale) => (
          <DropdownMenuItem
            key={locale.code}
            closeOnClick={false}
            onClick={() => onSelect(locale.code)}
          >
            {locale.name}
            {value === locale.code && <CheckIcon className="ml-auto size-3.5" />}
          </DropdownMenuItem>
        ))}
      </DropdownMenuSubContent>
    </DropdownMenuSub>
  )
}
