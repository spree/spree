import { Button } from "@/components/ui/button"
import { ChevronLeftIcon, ChevronRightIcon } from "lucide-react"

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
}

export function Pagination({ meta, onPageChange }: PaginationProps) {
  if (meta.pages <= 1) return null

  return (
    <div className="flex items-center justify-between border-t border-gray-200 bg-white px-4 py-3 rounded-b-2xl">
      <div className="text-sm text-muted-foreground">
        {meta.from}–{meta.to} of {meta.count}
      </div>
      <div className="flex items-center gap-1">
        <Button
          variant="ghost"
          size="icon-sm"
          disabled={!meta.previous}
          onClick={() => meta.previous && onPageChange(meta.previous)}
        >
          <ChevronLeftIcon className="size-4" />
        </Button>
        {generatePageNumbers(meta.page, meta.pages).map((p, i) =>
          p === "..." ? (
            <span key={`ellipsis-${i}`} className="px-1 text-sm text-muted-foreground">
              ...
            </span>
          ) : (
            <Button
              key={p}
              variant={p === meta.page ? "default" : "ghost"}
              size="icon-sm"
              onClick={() => onPageChange(p as number)}
            >
              {p}
            </Button>
          ),
        )}
        <Button
          variant="ghost"
          size="icon-sm"
          disabled={!meta.next}
          onClick={() => meta.next && onPageChange(meta.next)}
        >
          <ChevronRightIcon className="size-4" />
        </Button>
      </div>
    </div>
  )
}

function generatePageNumbers(current: number, total: number): (number | "...")[] {
  if (total <= 7) return Array.from({ length: total }, (_, i) => i + 1)

  const pages: (number | "...")[] = [1]

  if (current > 3) pages.push("...")

  const start = Math.max(2, current - 1)
  const end = Math.min(total - 1, current + 1)
  for (let i = start; i <= end; i++) pages.push(i)

  if (current < total - 2) pages.push("...")

  pages.push(total)
  return pages
}

export type { PaginationMeta }
