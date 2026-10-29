import { Fragment } from 'react'
import { Empty, EmptyDescription, EmptyHeader, EmptyMedia, EmptyTitle } from '../../ui/empty'
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle } from '../../ui/sheet'
import { CollapsibleCard } from '../collapsible-card'
import { CopyToClipboardButton } from '../copy-to-clipboard-button'
import { BracesIcon } from '../icons'

/**
 * Free-form metadata stored on a record. Read-only — apps and integrations
 * write to it; admins just see what's there.
 */
type Metadata = Record<string, unknown> | null | undefined

/** The keys external systems (ERP, PIM, CRM) know a record by, as `{ system => key }`. */
type ExternalReferences = Record<string, string> | null | undefined

interface MetadataListProps {
  metadata: Metadata
  externalReferences?: ExternalReferences
  /** Translated copy (passed by the app — these components stay headless). */
  emptyTitle: string
  emptyDescription: string
  /** Section headings, shown only when the record has both kinds of data. */
  metadataTitle?: string
  externalReferencesTitle?: string
  /** Accessible label for the copy button next to a system's key. */
  copyLabel?: (system: string) => string
}

export function hasMetadata(metadata: Metadata): metadata is Record<string, unknown> {
  return !!metadata && Object.keys(metadata).length > 0
}

export function hasExternalReferences(
  externalReferences: ExternalReferences,
): externalReferences is Record<string, string> {
  return !!externalReferences && Object.keys(externalReferences).length > 0
}

export function MetadataList({
  metadata,
  externalReferences,
  emptyTitle,
  emptyDescription,
  metadataTitle,
  externalReferencesTitle,
  copyLabel,
}: MetadataListProps) {
  const showMetadata = hasMetadata(metadata)
  const showReferences = hasExternalReferences(externalReferences)

  if (!showMetadata && !showReferences) {
    return (
      <Empty className="border-0 p-0">
        <EmptyHeader>
          <EmptyMedia variant="icon">
            <BracesIcon />
          </EmptyMedia>
          <EmptyTitle>{emptyTitle}</EmptyTitle>
          <EmptyDescription>{emptyDescription}</EmptyDescription>
        </EmptyHeader>
      </Empty>
    )
  }

  const both = showMetadata && showReferences

  return (
    <div className="flex flex-col gap-4">
      {showReferences && (
        <section className="flex flex-col gap-2">
          {externalReferencesTitle && (
            <h4 className="text-xs font-medium text-muted-foreground">{externalReferencesTitle}</h4>
          )}
          <dl className="grid grid-cols-[minmax(160px,1fr)_2fr] items-center gap-x-4 gap-y-1 text-sm">
            {Object.entries(externalReferences).map(([system, key]) => (
              <Fragment key={system}>
                <dt>
                  <code className="text-xs text-muted-foreground">{system}</code>
                </dt>
                <dd className="flex min-w-0 items-center gap-1 font-mono text-xs text-foreground/90">
                  <span className="break-all">{key}</span>
                  {copyLabel && (
                    <CopyToClipboardButton value={key} aria-label={copyLabel(system)} />
                  )}
                </dd>
              </Fragment>
            ))}
          </dl>
        </section>
      )}
      {showMetadata && (
        <section className="flex flex-col gap-2">
          {both && metadataTitle && (
            <h4 className="text-xs font-medium text-muted-foreground">{metadataTitle}</h4>
          )}
          <dl className="grid grid-cols-[minmax(160px,1fr)_2fr] gap-x-4 gap-y-2 text-sm">
            {Object.entries(metadata).map(([key, value]) => (
              <Fragment key={key}>
                <dt>
                  <code className="text-xs text-muted-foreground">{key}</code>
                </dt>
                <dd className="text-foreground/90 break-words font-mono text-xs">
                  {formatValue(value)}
                </dd>
              </Fragment>
            ))}
          </dl>
        </section>
      )}
    </div>
  )
}

interface MetadataCardProps extends MetadataListProps {
  title: string
}

/** Folded by default: metadata is for integrations, and the entry count says whether there is any. */
export function MetadataCard({ title, ...listProps }: MetadataCardProps) {
  return (
    <CollapsibleCard
      title={title}
      icon={<BracesIcon className="size-4" />}
      count={
        Object.keys(listProps.metadata ?? {}).length +
        Object.keys(listProps.externalReferences ?? {}).length
      }
    >
      <MetadataList {...listProps} />
    </CollapsibleCard>
  )
}

interface MetadataSheetProps extends MetadataListProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  title: string
  description?: string
}

/** Metadata of a record listed inside another page, opened from its row menu. */
export function MetadataSheet({
  open,
  onOpenChange,
  title,
  description,
  ...listProps
}: MetadataSheetProps) {
  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{title}</SheetTitle>
          {description && <SheetDescription>{description}</SheetDescription>}
        </SheetHeader>
        <div className="flex-1 overflow-y-auto p-4">
          <MetadataList {...listProps} />
        </div>
      </SheetContent>
    </Sheet>
  )
}

function formatValue(value: unknown): string {
  if (value === null || value === undefined) return '—'
  if (typeof value === 'string') return value
  if (typeof value === 'number' || typeof value === 'boolean') return String(value)
  return JSON.stringify(value)
}
