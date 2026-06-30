import type { Channel } from '@spree/admin-sdk'
import { ResourceMultiAutocomplete, useTranslation } from '@spree/dashboard-core'
import { Field, FieldGroup, FieldLabel } from '@spree/dashboard-ui'
import { useState } from 'react'
import { channelAutocompleteProps, useChannels } from '@/hooks/use-channels'
import { EditorShell } from './editor-shell'
import type { PromotionRuleEditorContext } from './types'

/**
 * Multi-select channel picker for the promotion Channel rule. Seeds from
 * `draft.channels` (the serializer embed, prefixed `ch_…` IDs) because
 * `preferences.channel_ids` holds raw integer IDs server-side. Writes the
 * selected ids back to `preferences.channel_ids` and the resolved records to
 * `draft.channels` for the rule summary.
 */
export function ChannelRuleEditor({ draft, onSave, onClose }: PromotionRuleEditorContext) {
  const { t } = useTranslation()
  // Preload the full channel list so the picker surfaces options on open
  // without the merchant having to type — the list is small and cached.
  const { data: channelsData } = useChannels()
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
          <FieldLabel>{t('admin.promotions.rules.channel.label')}</FieldLabel>
          <ResourceMultiAutocomplete
            {...channelAutocompleteProps('promotion-rule-channels')}
            initialItems={channelsData?.data}
            value={channelIds}
            onChange={setChannelIds}
            onResolvedOptionsChange={setChannels}
          />
        </Field>
      </FieldGroup>
    </EditorShell>
  )
}
