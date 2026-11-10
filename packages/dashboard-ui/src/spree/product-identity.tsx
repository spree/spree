import { mergeProps } from '@base-ui/react/merge-props'
import { useRender } from '@base-ui/react/use-render'
import type { ReactNode } from 'react'
import { cn } from '../lib/utils'
import { Thumbnail } from '../ui/thumbnail'
import { PackageIcon } from './icons'

export interface ProductIdentityProps extends useRender.ComponentProps<'span'> {
  name?: string | null
  /** A second line: the SKU, option values or a variant's name. */
  subtitle?: ReactNode
  thumbnailUrl?: string | null
  size?: 'sm' | 'md' | 'lg'
  /** Badges and other markers shown after the name. */
  badges?: ReactNode
  /** Strikes the name through, for a row that is about to be removed. */
  struckThrough?: boolean
}

/**
 * A product or variant, the same way in every list: its image, its name and
 * an optional second line.
 *
 * Pass `render` (a router link, or a button a table listens to) to make the
 * whole block the target — image and name together, never the name alone.
 */
export function ProductIdentity({
  name,
  subtitle,
  thumbnailUrl,
  size = 'md',
  badges,
  struckThrough,
  render,
  className,
  ...props
}: ProductIdentityProps) {
  const interactive = render !== undefined

  return useRender({
    defaultTagName: 'span',
    render,
    props: mergeProps<'span'>(
      {
        className: cn(
          'flex min-w-0 items-center gap-3 text-left text-foreground',
          interactive &&
            'group cursor-pointer rounded-md no-underline outline-none focus-visible:shadow-field-focus',
          className,
        ),
        children: (
          <>
            <Thumbnail src={thumbnailUrl} size={size} fallback={<PackageIcon />} />
            <span className="flex min-w-0 flex-col">
              <span className="flex min-w-0 items-center gap-2">
                <span
                  className={cn('truncate font-medium text-base', struckThrough && 'line-through')}
                >
                  {name ?? '—'}
                </span>
                {badges}
              </span>
              {subtitle && (
                <span className="truncate text-muted-foreground text-xs">{subtitle}</span>
              )}
            </span>
          </>
        ),
      },
      props,
    ),
    state: { slot: 'product-identity' },
  })
}
