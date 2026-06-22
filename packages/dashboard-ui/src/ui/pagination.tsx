import {
  ChevronLeftIcon,
  ChevronRightIcon,
  ChevronsLeftIcon,
  ChevronsRightIcon,
} from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { Button } from './button'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from './select'

interface PaginationMeta {
  page: number
  limit: number
  count: number
  pages: number
  from: number
  to: number
  previous: number | null
  next: number | null
}

interface PaginationProps {
  meta: PaginationMeta
  onPageChange: (page: number) => void
  onPageSizeChange?: (size: number) => void
  pageSizeOptions?: number[]
}

export function Pagination({
  meta,
  onPageChange,
  onPageSizeChange,
  pageSizeOptions = [10, 20, 25, 30, 50],
}: PaginationProps) {
  const { t } = useTranslation()

  if (meta.pages <= 1 && !onPageSizeChange) return null

  return (
    <div className="flex items-center justify-between border-t border-border px-4 py-3">
      <div className="text-sm text-muted-foreground">
        {t('admin.components.pagination.range', {
          from: meta.from,
          to: meta.to,
          count: meta.count,
        })}
      </div>
      <div className="flex items-center gap-6">
        {onPageSizeChange && (
          <div className="flex items-center gap-2">
            <span className="text-sm text-muted-foreground">
              {t('admin.components.pagination.rows_per_page')}
            </span>
            <Select
              value={`${meta.limit}`}
              onValueChange={(value) => onPageSizeChange(Number(value))}
            >
              <SelectTrigger className="h-8 w-[70px]">
                <SelectValue />
              </SelectTrigger>
              <SelectContent side="top">
                {pageSizeOptions.map((size) => (
                  <SelectItem key={size} value={`${size}`}>
                    {size}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        )}
        {meta.pages > 1 && (
          <>
            <span className="text-sm text-muted-foreground">
              {t('admin.common.page_of', { page: meta.page, total: meta.pages })}
            </span>
            <div className="flex items-center gap-1">
              <Button
                size="icon-sm"
                variant="outline"
                className="hidden lg:flex"
                disabled={!meta.previous}
                onClick={() => onPageChange(1)}
              >
                <span className="sr-only">{t('admin.components.pagination.first_page')}</span>
                <ChevronsLeftIcon />
              </Button>
              <Button
                size="icon-sm"
                variant="outline"
                disabled={!meta.previous}
                onClick={() => meta.previous && onPageChange(meta.previous)}
              >
                <span className="sr-only">{t('admin.components.pagination.previous_page')}</span>
                <ChevronLeftIcon />
              </Button>
              <Button
                size="icon-sm"
                variant="outline"
                disabled={!meta.next}
                onClick={() => meta.next && onPageChange(meta.next)}
              >
                <span className="sr-only">{t('admin.components.pagination.next_page')}</span>
                <ChevronRightIcon />
              </Button>
              <Button
                size="icon-sm"
                className="hidden lg:flex"
                variant="outline"
                disabled={!meta.next}
                onClick={() => onPageChange(meta.pages)}
              >
                <span className="sr-only">{t('admin.components.pagination.last_page')}</span>
                <ChevronsRightIcon />
              </Button>
            </div>
          </>
        )}
      </div>
    </div>
  )
}

export type { PaginationMeta }
