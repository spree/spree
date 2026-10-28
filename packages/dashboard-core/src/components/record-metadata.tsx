import { DropdownMenuItem, hasMetadata, MetadataCard, MetadataSheet } from '@spree/dashboard-ui'
import { BracesIcon } from '@spree/dashboard-ui/icons'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

type Metadata = Record<string, unknown> | null | undefined

/** Metadata card for the main column of a record's detail page. */
export function RecordMetadataCard({ metadata }: { metadata: Metadata }) {
  const { t } = useTranslation()
  return (
    <MetadataCard
      metadata={metadata}
      title={t('admin.components.metadata_card.title')}
      emptyTitle={t('admin.components.metadata_card.empty_title')}
      emptyDescription={t('admin.components.metadata_card.empty_description')}
    />
  )
}

/** Metadata of a row inside another page; pair with {@link ViewMetadataMenuItem}. */
function RecordMetadataSheet({
  metadata,
  open,
  onOpenChange,
  description,
}: {
  metadata: Metadata
  open: boolean
  onOpenChange: (open: boolean) => void
  /** Names the record, e.g. "Payment P123". */
  description?: string
}) {
  const { t } = useTranslation()
  return (
    <MetadataSheet
      open={open}
      onOpenChange={onOpenChange}
      metadata={metadata}
      title={t('admin.components.metadata_card.title')}
      description={description}
      emptyTitle={t('admin.components.metadata_card.empty_title')}
      emptyDescription={t('admin.components.metadata_card.empty_description')}
    />
  )
}

/**
 * One metadata sheet for a list of rows: `show` it from a row's menu and render
 * `sheet` once beside the list. The record stays set while the sheet animates
 * closed, so it never flashes the empty state on the way out.
 */
export function useMetadataSheet() {
  const [viewing, setViewing] = useState<{ metadata: Metadata; description?: string }>()
  const [open, setOpen] = useState(false)

  return {
    show(metadata: Metadata, description?: string) {
      setViewing({ metadata, description })
      setOpen(true)
    },
    sheet: (
      <RecordMetadataSheet
        metadata={viewing?.metadata}
        description={viewing?.description}
        open={open}
        onOpenChange={setOpen}
      />
    ),
  }
}

/** Renders nothing when the record has no metadata, so a menu needs no check of its own. */
export function ViewMetadataMenuItem({
  metadata,
  onClick,
}: {
  metadata: Metadata
  onClick: () => void
}) {
  const { t } = useTranslation()
  if (!hasMetadata(metadata)) return null

  return (
    <DropdownMenuItem onClick={onClick}>
      <BracesIcon className="size-4" />
      {t('admin.components.metadata_card.view')}
    </DropdownMenuItem>
  )
}

/** Metadata at the bottom of a record's edit sheet; renders nothing when there is none. */
export function RecordMetadataSection({ metadata }: { metadata: Metadata }) {
  return hasMetadata(metadata) ? <RecordMetadataCard metadata={metadata} /> : null
}
