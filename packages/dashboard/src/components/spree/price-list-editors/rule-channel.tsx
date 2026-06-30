import type { Channel } from '@spree/admin-sdk'
import { ResourceMultiAutocomplete } from '@spree/dashboard-core'
import { Field, FieldGroup, FieldLabel } from '@spree/dashboard-ui'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { EditorShell } from '@/components/spree/promotion-editors/editor-shell'
import { channelAutocompleteProps, useChannels } from '@/hooks/use-channels'
import type { PriceRuleEditorContext } from './types'

/**
 * Multi-select channel picker for the Channel price rule. Seeds from
 * `draft.channels` (the serializer embed, prefixed `ch_…` IDs) because
 * `preferences.channel_ids` holds raw integer IDs server-side. Writes the
 * selected ids back to `preferences.channel_ids` and the resolved records to
 * `draft.channels` for the rule summary.
 */
export function ChannelRuleEditor({ draft, onSave, onClose }: PriceRuleEditorContext) {
  const { t } = useTranslation()
  // Preload the full channel list so the picker surfaces options on open
  // without the merchant having to type — the list is small and cached.
  const { data: channelsData } = useChannels()
  // Seed from `draft.channels` (the embed) — `preferences.channel_ids`
  // holds raw integer IDs server-side while the embed carries the prefixed
  // `ch_…` IDs the picker round-trips.
  const [channelIds, setChannelIds] = useState<string[]>(() =>
    (draft.channels ?? []).map((c) => c.id),
  )
  const [channels, setChannels] = useState<Channel[]>(draft.channels ?? [])

  function handleSave() {
    onSave({
      ...draft,
      preferences: { ...draft.preferences, channel_ids: channelIds },
      channels,
    })
    onClose()
  }

  return (
    <EditorShell onSave={handleSave} onCancel={onClose} pending={false}>
      <FieldGroup>
        <Field>
          <FieldLabel>{t('admin.fields.price_rule.channels.label')}</FieldLabel>
          <ResourceMultiAutocomplete
            {...channelAutocompleteProps('price-rule-channels')}
            initialItems={channelsData?.data}
            value={channelIds}
            onChange={setChannelIds}
            onResolvedOptionsChange={setChannels}
          />
          <p className="text-xs text-muted-foreground">
            {t('admin.fields.price_rule.channels.help')}
          </p>
        </Field>
      </FieldGroup>
    </EditorShell>
  )
}
