'use client'

import { ContextMenu as ContextMenuPrimitive } from '@base-ui/react/context-menu'
import type * as React from 'react'
import { cn } from '../lib/utils'

/**
 * Right-click menu. Styled to match {@link DropdownMenu} exactly — the same
 * menu opened a different way should not look like a different menu.
 *
 * Always a shortcut to actions reachable another way: a right-click is
 * undiscoverable on its own, and absent entirely on touch.
 */
function ContextMenu({ ...props }: React.ComponentProps<typeof ContextMenuPrimitive.Root>) {
  return <ContextMenuPrimitive.Root data-slot="context-menu" {...props} />
}

function ContextMenuTrigger({
  ...props
}: React.ComponentProps<typeof ContextMenuPrimitive.Trigger>) {
  return <ContextMenuPrimitive.Trigger data-slot="context-menu-trigger" {...props} />
}

function ContextMenuGroup({ ...props }: React.ComponentProps<typeof ContextMenuPrimitive.Group>) {
  return <ContextMenuPrimitive.Group data-slot="context-menu-group" {...props} />
}

function ContextMenuContent({
  className,
  children,
  ...props
}: {
  className?: string
  children?: React.ReactNode
} & Omit<React.ComponentProps<typeof ContextMenuPrimitive.Popup>, 'className'>) {
  return (
    <ContextMenuPrimitive.Portal>
      <ContextMenuPrimitive.Positioner className="z-50">
        <ContextMenuPrimitive.Popup
          data-slot="context-menu-content"
          className={cn(
            // `origin-(--transform-origin)` so the menu grows out of the
            // pointer rather than its own centre.
            'z-50 max-h-[var(--available-height)] min-w-40 max-w-80 overflow-x-hidden overflow-y-auto rounded-2xl border border-border bg-popover p-1 text-popover-foreground shadow-lg origin-(--transform-origin) duration-100 ease-out data-[starting-style]:opacity-0 data-[starting-style]:scale-95 data-[ending-style]:opacity-0 data-[ending-style]:scale-95 transition-[opacity,transform,translate,scale]',
            className,
          )}
          {...props}
        >
          {children}
        </ContextMenuPrimitive.Popup>
      </ContextMenuPrimitive.Positioner>
    </ContextMenuPrimitive.Portal>
  )
}

function ContextMenuItem({
  className,
  inset,
  variant = 'default',
  ...props
}: React.ComponentProps<typeof ContextMenuPrimitive.Item> & {
  inset?: boolean
  variant?: 'default' | 'destructive'
}) {
  return (
    <ContextMenuPrimitive.Item
      data-slot="context-menu-item"
      data-inset={inset}
      data-variant={variant}
      className={cn(
        "group/context-menu-item relative flex cursor-pointer items-center gap-3 rounded-xl px-2 py-1.5 text-sm outline-hidden select-none transition-colors duration-75 focus:bg-accent focus:text-accent-foreground data-inset:pl-7 data-[variant=destructive]:text-destructive data-[variant=destructive]:focus:bg-destructive/10 data-[variant=destructive]:focus:text-destructive data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
        className,
      )}
      {...props}
    />
  )
}

function ContextMenuSeparator({
  className,
  ...props
}: React.ComponentProps<typeof ContextMenuPrimitive.Separator>) {
  return (
    <ContextMenuPrimitive.Separator
      data-slot="context-menu-separator"
      className={cn('mx-1 my-1 h-px bg-border-subtle', className)}
      {...props}
    />
  )
}

export {
  ContextMenu,
  ContextMenuContent,
  ContextMenuGroup,
  ContextMenuItem,
  ContextMenuSeparator,
  ContextMenuTrigger,
}
