import { type ReactNode, useState } from 'react'
import { cn } from '../lib/utils'
import { Badge } from '../ui/badge'
import { Card, CardContent, CardHeader } from '../ui/card'
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from '../ui/collapsible'
import { ChevronRightIcon } from './icons'

interface CollapsibleCardProps {
  title: ReactNode
  icon?: ReactNode
  /** Shown as a badge beside the title when above zero, so a closed card still says whether it holds anything. */
  count?: number
  /** Header controls kept outside the toggle, e.g. an Edit button. */
  actions?: ReactNode
  open?: boolean
  defaultOpen?: boolean
  onOpenChange?: (open: boolean) => void
  children: ReactNode
}

/** A secondary card that starts folded to its header, for content most visits don't need. */
export function CollapsibleCard({
  title,
  icon,
  count = 0,
  actions,
  open,
  defaultOpen = false,
  onOpenChange,
  children,
}: CollapsibleCardProps) {
  const [uncontrolledOpen, setUncontrolledOpen] = useState(defaultOpen)
  const isOpen = open ?? uncontrolledOpen

  function setOpen(next: boolean) {
    if (open === undefined) setUncontrolledOpen(next)
    onOpenChange?.(next)
  }

  return (
    <Card>
      <Collapsible open={isOpen} onOpenChange={setOpen}>
        <CardHeader
          className={cn('flex flex-row items-center gap-2 py-1.5', !isOpen && 'border-b-0')}
        >
          <CollapsibleTrigger className="group -mx-1 flex min-w-0 flex-1 cursor-pointer items-center gap-2 rounded-md px-1 py-1 text-left hover:bg-accent/50">
            <ChevronRightIcon className="size-4 shrink-0 text-muted-foreground transition-transform group-data-[panel-open]:rotate-90 motion-reduce:transition-none" />
            {/* CardTitle's styling on a span: a button may only hold phrasing content. */}
            <span
              data-slot="card-title"
              className="flex items-center gap-2 text-base font-semibold"
            >
              {icon}
              {title}
            </span>
            {count > 0 && <Badge variant="secondary">{count}</Badge>}
          </CollapsibleTrigger>
          {actions}
        </CardHeader>
        <CollapsibleContent>
          <CardContent>{children}</CardContent>
        </CollapsibleContent>
      </Collapsible>
    </Card>
  )
}
