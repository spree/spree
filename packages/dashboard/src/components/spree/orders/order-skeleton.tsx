import { Skeleton } from '@spree/dashboard-ui'

export function OrderSkeleton() {
  return (
    <div className="flex flex-col gap-6">
      {/* Mirrors PageHeader: the number on its own line, statuses and the
          timestamp on the one below, so the page does not reflow when the
          order lands. */}
      <div className="flex items-start gap-3">
        <Skeleton className="size-8 shrink-0 rounded-lg" />
        <div className="flex flex-col gap-1">
          <Skeleton className="h-8 w-40" />
          {/* Wraps like the real header's badge row, so a narrow viewport
              does not reflow the moment the order lands. */}
          <div className="flex flex-wrap items-center gap-3">
            <Skeleton className="h-5 w-20 shrink-0 rounded-md" />
            <Skeleton className="h-5 w-20 shrink-0 rounded-md" />
            <Skeleton className="h-4 w-32" />
          </div>
        </div>
      </div>
      <div className="grid grid-cols-12 gap-6">
        <div className="col-span-12 lg:col-span-8 flex flex-col gap-6">
          <Skeleton className="h-64 w-full rounded-xl" />
          <Skeleton className="h-48 w-full rounded-xl" />
          <Skeleton className="h-48 w-full rounded-xl" />
        </div>
        <div className="col-span-12 lg:col-span-4 flex flex-col gap-6">
          <Skeleton className="h-64 w-full rounded-xl" />
        </div>
      </div>
    </div>
  )
}
