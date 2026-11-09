import type { ReactNode } from 'react'
import { cn } from '../lib/utils'
import { Item, ItemContent, ItemDescription, ItemTitle } from '../ui/item'

/**
 * One figure in a row of headline numbers at the top of a record page: a
 * small label over a large value, each in its own outline item. Lay several
 * out in a grid rather than inside a card.
 */
export function StatItem({
  label,
  value,
  className,
}: {
  label: ReactNode
  value: ReactNode
  className?: string
}) {
  return (
    <Item variant="outline" className={cn('items-start', className)}>
      <ItemContent>
        <ItemDescription>{label}</ItemDescription>
        <ItemTitle className="text-lg font-semibold">{value}</ItemTitle>
      </ItemContent>
    </Item>
  )
}
