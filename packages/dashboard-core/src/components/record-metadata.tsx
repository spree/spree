import {
  DropdownMenuItem,
  hasExternalReferences,
  hasMetadata,
  MetadataCard,
  MetadataSheet,
} from '@spree/dashboard-ui'
import { BracesIcon } from '@spree/dashboard-ui/icons'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

type Metadata = Record<string, unknown> | null | undefined
type ExternalReferences = Record<string, string> | null | undefined

interface RecordIntegrationData {
  metadata?: Metadata
  /** The record's `external_references` map, on records that carry one. */
  externalReferences?: ExternalReferences
}

function useMetadataCopy() {
  const { t } = useTranslation()
  return {
    title: t('admin.components.metadata_card.title'),
    metadataTitle: t('admin.components.metadata_card.title'),
    externalReferencesTitle: t('admin.components.metadata_card.external_references'),
    copyLabel: (system: string) => t('admin.components.metadata_card.copy_reference', { system }),
    emptyTitle: t('admin.components.metadata_card.empty_title'),
    emptyDescription: t('admin.components.metadata_card.empty_description'),
  }
}

function hasIntegrationData({ metadata, externalReferences }: RecordIntegrationData) {
  return hasMetadata(metadata) || hasExternalReferences(externalReferences)
}

/** Metadata card for the main column of a record's detail page. */
export function RecordMetadataCard({ metadata, externalReferences }: RecordIntegrationData) {
  return (
    <MetadataCard
      metadata={metadata}
      externalReferences={externalReferences}
      {...useMetadataCopy()}
    />
  )
}

/** Metadata of a row inside another page; pair with {@link ViewMetadataMenuItem}. */
function RecordMetadataSheet({
  metadata,
  externalReferences,
  open,
  onOpenChange,
  description,
}: RecordIntegrationData & {
  open: boolean
  onOpenChange: (open: boolean) => void
  /** Names the record, e.g. "Payment P123". */
  description?: string
}) {
  return (
    <MetadataSheet
      open={open}
      onOpenChange={onOpenChange}
      metadata={metadata}
      externalReferences={externalReferences}
      description={description}
      {...useMetadataCopy()}
    />
  )
}

/**
 * One metadata sheet for a list of rows: `show` it from a row's menu and render
 * `sheet` once beside the list. The record stays set while the sheet animates
 * closed, so it never flashes the empty state on the way out.
 */
export function useMetadataSheet() {
  const [viewing, setViewing] = useState<RecordIntegrationData & { description?: string }>()
  const [open, setOpen] = useState(false)

  return {
    show(metadata: Metadata, description?: string, externalReferences?: ExternalReferences) {
      setViewing({ metadata, description, externalReferences })
      setOpen(true)
    },
    sheet: (
      <RecordMetadataSheet
        metadata={viewing?.metadata}
        externalReferences={viewing?.externalReferences}
        description={viewing?.description}
        open={open}
        onOpenChange={setOpen}
      />
    ),
  }
}

/** Renders nothing when the record has no metadata, so a menu needs no check of its own. */
export function ViewMetadataMenuItem({
  onClick,
  ...data
}: RecordIntegrationData & { onClick: () => void }) {
  const { t } = useTranslation()
  if (!hasIntegrationData(data)) return null

  return (
    <DropdownMenuItem onClick={onClick}>
      <BracesIcon className="size-4" />
      {t('admin.components.metadata_card.view')}
    </DropdownMenuItem>
  )
}

/** Metadata at the bottom of a record's edit sheet; renders nothing when there is none. */
export function RecordMetadataSection(data: RecordIntegrationData) {
  return hasIntegrationData(data) ? <RecordMetadataCard {...data} /> : null
}
