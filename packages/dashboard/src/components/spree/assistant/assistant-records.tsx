import type { AssistantRecord } from '@spree/admin-sdk'
import { useStore } from '@spree/dashboard-core'
import { Badge } from '@spree/dashboard-ui'
import { ChevronRightIcon, ImageIcon } from '@spree/dashboard-ui/icons'
import { useNavigate } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'

interface AssistantRecordsProps {
  records: AssistantRecord[]
  /** Records that matched, which can exceed the rows shown. */
  total?: number
}

/**
 * Records a read tool found, as rows the merchant can click through to.
 *
 * The point of showing them rather than letting the assistant describe them:
 * an answer about a product is usually the start of working on that product.
 */
export function AssistantRecords({ records, total }: AssistantRecordsProps) {
  const { t } = useTranslation()
  const { storeId } = useStore()
  const navigate = useNavigate()
  const hidden = Math.max((total ?? records.length) - records.length, 0)

  return (
    <div className="overflow-hidden rounded-lg border">
      <ul className="divide-y">
        {records.map((record) => {
          const href = record.path ? `/${storeId}${record.path}` : null

          return (
            <li key={record.id}>
              <button
                type="button"
                // Records the dashboard has no page for still read fine; they
                // just don't invite a click.
                disabled={!href}
                onClick={() => href && navigate({ to: href })}
                className="flex w-full items-center gap-3 px-3 py-2 text-left transition-colors enabled:hover:bg-accent disabled:cursor-default"
              >
                {/* The placeholder sits underneath, so an image that fails to
                    load (a misconfigured asset host, a purged blob) leaves a
                    tidy row rather than a broken-image glyph. */}
                <span className="relative flex size-8 shrink-0 items-center justify-center overflow-hidden rounded bg-muted">
                  <ImageIcon className="size-4 text-muted-foreground" />
                  {record.image_url && (
                    <img
                      src={record.image_url}
                      alt=""
                      loading="lazy"
                      className="absolute inset-0 size-full object-cover"
                      onError={(event) => {
                        event.currentTarget.style.display = 'none'
                      }}
                    />
                  )}
                </span>

                <span className="min-w-0 flex-1">
                  <span className="block truncate font-medium text-sm">{record.title}</span>
                  {record.subtitle && (
                    <span className="block truncate text-muted-foreground text-xs">
                      {record.subtitle}
                    </span>
                  )}
                </span>

                {record.status && (
                  <Badge variant="secondary" className="shrink-0 font-normal">
                    {record.status}
                  </Badge>
                )}

                {href && <ChevronRightIcon className="size-4 shrink-0 text-muted-foreground" />}
              </button>
            </li>
          )
        })}
      </ul>

      {hidden > 0 && (
        <p className="border-t bg-muted/40 px-3 py-1.5 text-muted-foreground text-xs">
          {t('admin.assistant.more_records', { count: hidden })}
        </p>
      )}
    </div>
  )
}
