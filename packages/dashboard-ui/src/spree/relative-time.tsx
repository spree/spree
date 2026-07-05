import { format, formatDistanceToNow } from 'date-fns'
import type { ComponentProps, ReactNode } from 'react'
import { activeDateLocale } from '../lib/date-locale'
import { cn } from '../lib/utils'
import { Tooltip, TooltipContent, TooltipTrigger } from '../ui/tooltip'

type TooltipContentProps = ComponentProps<typeof TooltipContent>

type RelativeTimeProps = {
  iso: string | null | undefined
  fallback?: ReactNode
  prefix?: ReactNode
  className?: string
  side?: TooltipContentProps['side']
  align?: TooltipContentProps['align']
}

export function RelativeTime({
  iso,
  fallback = '—',
  prefix,
  className,
  side,
  align,
}: RelativeTimeProps) {
  if (!iso) return <>{fallback}</>

  const date = new Date(iso)
  if (Number.isNaN(date.getTime())) return <>{fallback}</>

  const locale = activeDateLocale()
  const relative = formatDistanceToNow(date, { addSuffix: true, locale })
  const absolute = format(date, 'PPpp', { locale })

  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <time dateTime={iso} className={cn('cursor-default', className)}>
          {prefix}
          {prefix ? ' ' : null}
          {relative}
        </time>
      </TooltipTrigger>
      <TooltipContent side={side} align={align}>
        {absolute}
      </TooltipContent>
    </Tooltip>
  )
}
