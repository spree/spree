import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Empty,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
  Skeleton,
} from '@spree/dashboard-ui'
import { TriangleAlertIcon } from '@spree/dashboard-ui/icons'
import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'

/**
 * A short settings list in a card: title, one line of help, an add button,
 * then the rows. For vocabularies a merchant reads in one go (reasons, tax
 * categories, tax rates), where a full resource table's search, filters and
 * column picker would be more chrome than content.
 */
export function SettingsListCard({
  title,
  description,
  action,
  isLoading,
  isError,
  isEmpty,
  emptyIcon,
  emptyTitle,
  children,
  footer,
}: {
  title: string
  description?: string
  action?: ReactNode
  isLoading: boolean
  isError: boolean
  isEmpty: boolean
  emptyIcon: ReactNode
  emptyTitle: string
  /** The table, rendered once the rows have loaded and there is at least one. */
  children: ReactNode
  /** Rendered under the table, such as its pagination. */
  footer?: ReactNode
}) {
  const { t } = useTranslation()

  return (
    <Card>
      <CardHeader className="flex flex-row items-start justify-between gap-3 space-y-0">
        <div>
          <CardTitle>{title}</CardTitle>
          {description && <p className="mt-1 text-sm text-muted-foreground">{description}</p>}
        </div>
        {action}
      </CardHeader>
      <CardContent className="p-0">
        {isLoading ? (
          <div className="p-4">
            <Skeleton className="h-10 w-full" />
          </div>
        ) : isError ? (
          // Distinct from the empty state: "nothing here yet" would tell an
          // admin the list is empty when the request actually failed.
          <Empty>
            <EmptyHeader>
              <EmptyMedia variant="icon">
                <TriangleAlertIcon />
              </EmptyMedia>
              <EmptyTitle>{t('admin.errors.failed_to_load')}</EmptyTitle>
            </EmptyHeader>
          </Empty>
        ) : isEmpty ? (
          <Empty>
            <EmptyHeader>
              <EmptyMedia variant="icon">{emptyIcon}</EmptyMedia>
              <EmptyTitle>{emptyTitle}</EmptyTitle>
            </EmptyHeader>
          </Empty>
        ) : (
          <>
            {children}
            {footer}
          </>
        )}
      </CardContent>
    </Card>
  )
}
