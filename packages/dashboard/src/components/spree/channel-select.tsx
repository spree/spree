import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@spree/dashboard-ui'
import { useTranslation } from 'react-i18next'
import { useChannels } from '@/hooks/use-channels'

interface ChannelSelectProps {
  /** ID for the trigger — paired with the parent `<FieldLabel htmlFor>`. */
  id?: string
  /** Submit name — a hidden input mirrors the value so plain `FormData` works. */
  name?: string
  /** Controlled value. Pair with `onChange` to lift state out. */
  value?: string
  /** Fires on every selection change. */
  onChange?: (channelId: string) => void
  /** Placeholder shown when no channel is selected. */
  placeholder?: string
  disabled?: boolean
}

/**
 * Picker for one of the current store's channels. Mirrors `<CurrencySelect>`:
 * cached at the hook layer (5-min stale time via `useChannels`), shared across
 * forms, with the same `CODE — Name` rendering pattern in the trigger so the
 * selected value reads identically whether the dropdown is open or closed.
 * Use anywhere the merchant attributes an admin-side action to a sales
 * channel (manual orders, exports, scoped reports).
 */
export function ChannelSelect({
  id,
  name,
  value,
  onChange,
  placeholder,
  disabled,
}: ChannelSelectProps) {
  const { t } = useTranslation()
  const { data } = useChannels()
  const channels = data?.data ?? []

  return (
    <>
      {name && <input type="hidden" name={name} value={value ?? ''} />}
      <Select value={value ?? ''} onValueChange={(v) => onChange?.(v)} disabled={disabled}>
        <SelectTrigger id={id}>
          {/* Base UI's `<SelectValue>` defaults to rendering the raw `value`
              (the prefixed ID). Use the children render-prop to look up the
              name from our cached list so the trigger matches the items. */}
          <SelectValue
            placeholder={placeholder ?? t('admin.components.channel_select.placeholder')}
          >
            {(v) =>
              channels.find((c) => c.id === v)?.name ??
              placeholder ??
              t('admin.components.channel_select.placeholder')
            }
          </SelectValue>
        </SelectTrigger>
        <SelectContent>
          {channels.map((c) => (
            <SelectItem key={c.id} value={c.id}>
              {c.name}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </>
  )
}
