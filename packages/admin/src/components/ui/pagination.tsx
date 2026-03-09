import {
  ChevronLeftIcon,
  ChevronRightIcon,
  ChevronsLeftIcon,
  ChevronsRightIcon,
} from 'lucide-react'
import { Button } from '@/components/ui/button'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'

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
  if (meta.pages <= 1 && !onPageSizeChange) return null

  return (
    <div className="flex items-center justify-between border-t border-gray-200 px-4 py-3">
      <div className="text-sm text-muted-foreground">
        {meta.from}&ndash;{meta.to} of {meta.count}
      </div>
      <div className="flex items-center gap-6">
        {onPageSizeChange && (
          <div className="flex items-center gap-2">
            <span className="text-sm text-muted-foreground">Rows per page</span>
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
              Page {meta.page} of {meta.pages}
            </span>
            <div className="flex items-center gap-1">
              <Button
                variant="outline"
                size="icon-sm"
                className="hidden lg:flex"
                disabled={!meta.previous}
                onClick={() => onPageChange(1)}
              >
                <span className="sr-only">Go to first page</span>
                <ChevronsLeftIcon />
              </Button>
              <Button
                variant="outline"
                size="icon-sm"
                disabled={!meta.previous}
                onClick={() => meta.previous && onPageChange(meta.previous)}
              >
                <span className="sr-only">Go to previous page</span>
                <ChevronLeftIcon />
              </Button>
              <Button
                variant="outline"
                size="icon-sm"
                disabled={!meta.next}
                onClick={() => meta.next && onPageChange(meta.next)}
              >
                <span className="sr-only">Go to next page</span>
                <ChevronRightIcon />
              </Button>
              <Button
                variant="outline"
                size="icon-sm"
                className="hidden lg:flex"
                disabled={!meta.next}
                onClick={() => onPageChange(meta.pages)}
              >
                <span className="sr-only">Go to last page</span>
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
