import { ResourceMultiAutocomplete } from '@spree/dashboard-core'
import { Field, FieldGroup, FieldLabel } from '@spree/dashboard-ui'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { channelAutocompleteProps, useChannels } from '../../../hooks/use-channels'
import type { RuleEmbedRecord } from '../../../schemas/price-list'
import { EditorShell } from '../promotion-editors/editor-shell'
import type { PriceRuleEditorContext } from './types'

/**
 * Multi-select channel picker for the Channel price rule. Reads and writes
 * the prefixed ids in `preferences.channel_ids`, and keeps the resolved
 * records in `draft.channels` for the rule summary.
 */
export function ChannelRuleEditor({ draft, onSave, onClose }: PriceRuleEditorContext) {
  const { t } = useTranslation()
  // Preload the full channel list so the picker surfaces options on open
  // without the merchant having to type — the list is small and cached.
  const { data: channelsData } = useChannels()
  const [channelIds, setChannelIds] = useState<string[]>(
    () => (draft.preferences?.channel_ids ?? []) as string[],
  )
  const [channels, setChannels] = useState<RuleEmbedRecord[]>(draft.channels ?? [])

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
