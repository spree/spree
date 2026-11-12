import {
  Combobox,
  ComboboxChip,
  ComboboxChips,
  ComboboxChipsInput,
  ComboboxContent,
  ComboboxEmpty,
  ComboboxItem,
  ComboboxList,
  ComboboxValue,
  useComboboxAnchor,
} from '@spree/dashboard-ui'
import { useCallback, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  CONTENT_TYPE_FAMILIES,
  DIGITAL_FILE_CONTENT_TYPES,
  isMediaType,
} from '../../schemas/marketplace'

const KNOWN_FORMATS = new Map(DIGITAL_FILE_CONTENT_TYPES.map((type) => [type.value, type.format]))
const FAMILY_WILDCARDS = CONTENT_TYPE_FAMILIES.map((family) => `${family}/*`)

/**
 * Chips picker for a list of content types. The dropdown offers the formats
 * digital goods usually come in, named by format (`PDF`, `FLAC`) as well as by
 * type, and a whole family at once (`audio/*`). A type that is not listed is
 * typed in and added with Enter, as long as it has the `type/subtype` shape.
 */
export function ContentTypeCombobox({
  id,
  value,
  onChange,
  invalid,
  disabled = false,
}: {
  /** Forwarded to the chips input so a `<FieldLabel htmlFor>` can target it. */
  id?: string
  value: string[]
  onChange: (next: string[]) => void
  invalid?: boolean
  disabled?: boolean
}) {
  const { t } = useTranslation()
  const anchorRef = useComboboxAnchor()
  const [inputValue, setInputValue] = useState('')

  const labelFor = useCallback(
    (type: string): string => {
      const family = type.endsWith('/*') ? type.slice(0, -2) : null
      if (family) {
        return t(`admin.fields.store.seller_digital_asset_content_types.families.${family}`, {
          defaultValue: type,
        })
      }
      const format = KNOWN_FORMATS.get(type)
      return format ? `${format} · ${type}` : type
    },
    [t],
  )

  // The known list plus whatever is already selected, so a type added by hand
  // or through the API keeps its chip. The typed value joins the list once it
  // is a well-formed type, so it can be picked from the dropdown as well as
  // added with Enter.
  const typed = inputValue.trim().toLowerCase()
  const items = useMemo(() => {
    const set = new Set([...FAMILY_WILDCARDS, ...KNOWN_FORMATS.keys(), ...value])
    if (typed && isMediaType(typed)) set.add(typed)
    return Array.from(set)
  }, [value, typed])

  const addTyped = () => {
    if (!typed || !isMediaType(typed)) return
    if (!value.includes(typed)) onChange([...value, typed])
    setInputValue('')
  }

  return (
    <Combobox
      multiple
      items={items}
      value={value}
      onValueChange={(next: string[]) => {
        onChange(next)
        setInputValue('')
      }}
      itemToStringLabel={labelFor}
      filter={(type: string, query: string) => {
        const needle = query.trim().toLowerCase()
        return !needle || type.includes(needle) || labelFor(type).toLowerCase().includes(needle)
      }}
      disabled={disabled}
    >
      <ComboboxChips ref={anchorRef}>
        <ComboboxValue>
          {(selected: string[]) =>
            selected.map((type) => (
              <ComboboxChip key={type} className="font-mono text-xs">
                {type}
              </ComboboxChip>
            ))
          }
        </ComboboxValue>
        <ComboboxChipsInput
          id={id}
          aria-invalid={invalid || undefined}
          placeholder={t('admin.fields.store.seller_digital_asset_content_types.placeholder')}
          value={inputValue}
          onChange={(event) => setInputValue((event.target as HTMLInputElement).value)}
          onKeyDown={(event) => {
            if (event.key !== 'Enter' || !typed) return
            event.preventDefault()
            addTyped()
          }}
          autoComplete="off"
          autoCorrect="off"
          autoCapitalize="off"
          spellCheck={false}
        />
      </ComboboxChips>
      <ComboboxContent anchor={anchorRef}>
        <ComboboxEmpty>
          {t('admin.fields.store.seller_digital_asset_content_types.empty_hint')}
        </ComboboxEmpty>
        <ComboboxList>
          {(type: string) => (
            <ComboboxItem key={type} value={type}>
              {KNOWN_FORMATS.has(type) || type.endsWith('/*') || value.includes(type)
                ? labelFor(type)
                : t('admin.fields.store.seller_digital_asset_content_types.add_option', { type })}
            </ComboboxItem>
          )}
        </ComboboxList>
      </ComboboxContent>
    </Combobox>
  )
}
