'use client'

import { Dialog as SheetPrimitive } from '@base-ui/react/dialog'
import { XIcon } from 'lucide-react'
import * as React from 'react'
import { Button } from '@/components/ui/button'
import { cn } from '@/lib/utils'

function Sheet({
  children,
  open,
  defaultOpen,
  onOpenChange,
  modal,
  ...props
}: {
  children?: React.ReactNode
  open?: boolean
  defaultOpen?: boolean
  onOpenChange?: (open: boolean, eventDetails: SheetPrimitive.Root.ChangeEventDetails) => void
  /**
   * `true` (default) — full modal: focus trap + scroll lock + outside pointer interactions disabled.
   * `'trap-focus'` — focus trap only; outside pointer interactions remain enabled.
   * `false` — no modal behavior.
   *
   * Use `'trap-focus'` when the sheet contains a contenteditable (e.g. tiptap)
   * — the full-modal pointer-down listeners on `document` with `capture: true`
   * race with ProseMirror's own pointer handlers and break click-to-focus.
   */
  modal?: boolean | 'trap-focus'
}) {
  return (
    <SheetPrimitive.Root
      data-slot="sheet"
      open={open}
      defaultOpen={defaultOpen}
      onOpenChange={onOpenChange}
      modal={modal}
      {...props}
    >
      {children}
    </SheetPrimitive.Root>
  )
}

function SheetTrigger({
  asChild,
  children,
  ...props
}: React.ComponentProps<typeof SheetPrimitive.Trigger> & {
  asChild?: boolean
}) {
  if (asChild && React.isValidElement(children)) {
    return <SheetPrimitive.Trigger data-slot="sheet-trigger" render={children} {...props} />
  }
  return (
    <SheetPrimitive.Trigger data-slot="sheet-trigger" {...props}>
      {children}
    </SheetPrimitive.Trigger>
  )
}

function SheetClose({
  asChild,
  children,
  ...props
}: React.ComponentProps<typeof SheetPrimitive.Close> & {
  asChild?: boolean
}) {
  if (asChild && React.isValidElement(children)) {
    return <SheetPrimitive.Close data-slot="sheet-close" render={children} {...props} />
  }
  return (
    <SheetPrimitive.Close data-slot="sheet-close" {...props}>
      {children}
    </SheetPrimitive.Close>
  )
}

function SheetPortal({ children, ...props }: React.ComponentProps<typeof SheetPrimitive.Portal>) {
  return (
    <SheetPrimitive.Portal data-slot="sheet-portal" {...props}>
      {children}
    </SheetPrimitive.Portal>
  )
}

function SheetOverlay({
  className,
  ...props
}: React.ComponentProps<typeof SheetPrimitive.Backdrop>) {
  return (
    <SheetPrimitive.Backdrop
      data-slot="sheet-overlay"
      className={cn(
        'fixed inset-0 z-50 bg-gray-100/75 dark:bg-black/60 duration-200 data-[starting-style]:opacity-0 data-[ending-style]:opacity-0 transition-opacity',
        className,
      )}
      {...props}
    />
  )
}

function SheetContent({
  className,
  children,
  side = 'right',
  showCloseButton = true,
  dir,
  ...props
}: React.ComponentProps<typeof SheetPrimitive.Popup> & {
  side?: 'top' | 'right' | 'bottom' | 'left'
  showCloseButton?: boolean
  dir?: string
}) {
  return (
    <SheetPortal>
      <SheetOverlay />
      <SheetPrimitive.Popup
        data-slot="sheet-content"
        data-side={side}
        dir={dir}
        className={cn(
          'fixed z-50 flex flex-col border border-border bg-background text-foreground text-sm shadow-sm transition duration-250 ease-out',
          'data-[side=right]:inset-y-0 data-[side=right]:right-0 data-[side=right]:h-[calc(100dvh-1rem)] data-[side=right]:max-h-[calc(100dvh-1rem)] data-[side=right]:w-[calc(100vw-1rem)] data-[side=right]:max-w-[600px] data-[side=right]:min-w-[320px] data-[side=right]:m-2 data-[side=right]:rounded-xl',
          'data-[side=left]:inset-y-0 data-[side=left]:left-0 data-[side=left]:h-full data-[side=left]:w-3/4 data-[side=left]:border-r data-[side=left]:sm:max-w-sm',
          'data-[side=bottom]:inset-x-0 data-[side=bottom]:bottom-0 data-[side=bottom]:h-auto data-[side=bottom]:border-t',
          'data-[side=top]:inset-x-0 data-[side=top]:top-0 data-[side=top]:h-auto data-[side=top]:border-b',
          'data-[starting-style]:opacity-0 data-[side=right]:data-[starting-style]:translate-x-10 data-[side=left]:data-[starting-style]:-translate-x-10 data-[side=bottom]:data-[starting-style]:translate-y-10 data-[side=top]:data-[starting-style]:-translate-y-10',
          'data-[ending-style]:opacity-0 data-[side=right]:data-[ending-style]:translate-x-10 data-[side=left]:data-[ending-style]:-translate-x-10 data-[side=bottom]:data-[ending-style]:translate-y-10 data-[side=top]:data-[ending-style]:-translate-y-10',
          className,
        )}
        {...props}
      >
        {children}
        {showCloseButton && (
          <SheetPrimitive.Close
            data-slot="sheet-close"
            render={
              <Button variant="ghost" className="absolute top-3 right-3" size="icon-sm">
                <XIcon />
                <span className="sr-only">Close</span>
              </Button>
            }
          />
        )}
      </SheetPrimitive.Popup>
    </SheetPortal>
  )
}

function SheetHeader({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="sheet-header"
      className={cn('relative flex flex-col gap-1.5 border-b p-4 pr-12', className)}
      {...props}
    />
  )
}

function SheetFooter({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="sheet-footer"
      className={cn(
        'flex flex-col-reverse gap-2 border-t bg-muted/50 p-4 sm:flex-row sm:justify-end rounded-b-xl',
        className,
      )}
      {...props}
    />
  )
}

function SheetTitle({ className, ...props }: React.ComponentProps<typeof SheetPrimitive.Title>) {
  return (
    <SheetPrimitive.Title
      data-slot="sheet-title"
      className={cn('text-base leading-none font-medium', className)}
      {...props}
    />
  )
}

function SheetDescription({
  className,
  ...props
}: React.ComponentProps<typeof SheetPrimitive.Description>) {
  return (
    <SheetPrimitive.Description
      data-slot="sheet-description"
      className={cn('text-sm text-muted-foreground', className)}
      {...props}
    />
  )
}

export {
  Sheet,
  SheetClose,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
}
