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
import { useQuery } from '@tanstack/react-query'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { adminClient } from '../client'
import { useAuth } from '../hooks/use-auth'
import type { TaggableType } from '../lib/table-registry'

export type { TaggableType }

export function TagCombobox({
  taggableType,
  value,
  onChange,
  placeholder,
}: {
  taggableType: TaggableType
  value: string[]
  onChange: (value: string[]) => void
  placeholder?: string
}) {
  const { t } = useTranslation()
  const resolvedPlaceholder = placeholder ?? t('admin.components.tag_combobox.placeholder')
  const anchorRef = useComboboxAnchor()
  const [inputValue, setInputValue] = useState('')
  const { isAuthenticated } = useAuth()

  const { data } = useQuery({
    queryKey: ['admin-tags', taggableType],
    queryFn: () => adminClient.tags.list({ taggable_type: taggableType }),
    enabled: isAuthenticated,
    staleTime: 60_000,
  })

  const existingTags = data?.data?.map((t) => t.name) ?? []

  // Append the typed value as a "Create" candidate so the user can confirm new tags
  // via the dropdown (in addition to the Enter shortcut).
  const items = useMemo(() => {
    const set = new Set([...existingTags, ...value])
    const trimmed = inputValue.trim()
    if (trimmed) set.add(trimmed)
    return Array.from(set)
  }, [existingTags, value, inputValue])

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter' && inputValue.trim()) {
      e.preventDefault()
      const tag = inputValue.trim()
      if (!value.includes(tag)) onChange([...value, tag])
      setInputValue('')
    }
  }

  return (
    <Combobox multiple items={items} value={value} onValueChange={onChange}>
      <ComboboxChips ref={anchorRef}>
        <ComboboxValue>
          {(selectedValues: string[]) =>
            selectedValues.map((tag) => <ComboboxChip key={tag}>{tag}</ComboboxChip>)
          }
        </ComboboxValue>
        <ComboboxChipsInput
          placeholder={resolvedPlaceholder}
          value={inputValue}
          onChange={(e) => setInputValue((e.target as HTMLInputElement).value)}
          onKeyDown={handleKeyDown}
        />
      </ComboboxChips>
      <ComboboxContent anchor={anchorRef}>
        <ComboboxEmpty>{t('admin.components.tag_combobox.empty_hint')}</ComboboxEmpty>
        <ComboboxList>
          {(tag: string) => {
            const isSelected = value.includes(tag)
            const isExisting = existingTags.includes(tag)
            return (
              <ComboboxItem key={tag} value={tag}>
                {isExisting || isSelected
                  ? tag
                  : t('admin.components.tag_combobox.create_option', { tag })}
              </ComboboxItem>
            )
          }}
        </ComboboxList>
      </ComboboxContent>
    </Combobox>
  )
}
