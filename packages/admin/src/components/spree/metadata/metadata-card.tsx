import { BracesIcon } from 'lucide-react'
import { Fragment } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Empty, EmptyDescription, EmptyHeader, EmptyMedia, EmptyTitle } from '@/components/ui/empty'

interface MetadataCardProps {
  /**
   * Free-form metadata stored on the record. Read-only — apps and integrations
   * write to this; admins just see what's there. Always an object (possibly
   * empty); the API never returns `null`.
   */
  metadata: Record<string, unknown>
}

export function MetadataCard({ metadata }: MetadataCardProps) {
  const entries = Object.entries(metadata)

  return (
    <Card>
      <CardHeader>
        <CardTitle>Metadata</CardTitle>
      </CardHeader>
      <CardContent>
        {entries.length === 0 ? (
          <Empty className="border-0 p-0">
            <EmptyHeader>
              <EmptyMedia variant="icon">
                <BracesIcon />
              </EmptyMedia>
              <EmptyTitle>No metadata</EmptyTitle>
              <EmptyDescription>
                Apps and integrations populate this automatically.
              </EmptyDescription>
            </EmptyHeader>
          </Empty>
        ) : (
          <dl className="grid grid-cols-[minmax(160px,1fr)_2fr] gap-x-4 gap-y-2 text-sm">
            {entries.map(([key, value]) => (
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
        )}
      </CardContent>
    </Card>
  )
}

function formatValue(value: unknown): string {
  if (value === null || value === undefined) return '—'
  if (typeof value === 'string') return value
  if (typeof value === 'number' || typeof value === 'boolean') return String(value)
  return JSON.stringify(value)
}
