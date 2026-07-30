import { CheckIcon, ChevronsUpDownIcon } from 'lucide-react'
import {
  DropdownMenuItem,
  DropdownMenuSub,
  DropdownMenuSubContent,
  DropdownMenuSubTrigger,
} from '../ui/dropdown-menu'

interface LanguageMenuItemsProps {
  /** Translated "Language" label for the row (passed by the app). */
  label: string
  /** Admin UI languages available to switch to ({ code, name } pairs). */
  locales: ReadonlyArray<{ code: string; name: string }>
  /** Currently active language code. */
  value: string
  onSelect: (code: string) => void
}

/**
 * Admin UI language picker rendered inside the user dropdown's Preferences
 * section. The row shows a select-style pill with the current language; opening
 * it reveals the full list as a nested submenu (kept within the menu system so
 * it stays robust inside the dropdown's portal tree).
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
      <DropdownMenuSubTrigger hideChevron className="justify-between">
        <span className="text-sm text-foreground">{label}</span>
        <span className="ml-auto inline-flex items-center gap-1.5 rounded-lg border border-border bg-card px-2 py-1 text-xs font-normal text-foreground">
          {current?.name ?? value}
          <ChevronsUpDownIcon className="size-3 text-muted-foreground" />
        </span>
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
