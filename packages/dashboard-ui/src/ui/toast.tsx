'use client'

import { Toast as ToastPrimitive } from '@base-ui/react/toast'
import i18n from 'i18next'
import type * as React from 'react'
import { cn } from '../lib/utils'
import {
  CircleCheckIcon,
  InfoIcon,
  Loader2Icon,
  OctagonXIcon,
  TriangleAlertIcon,
  XIcon,
} from '../spree/icons'
import { Button } from './button'

/**
 * App-wide toast manager. Created outside React so a toast can be raised from
 * anywhere — a mutation hook, an event subscriber, a plain async function —
 * without threading a hook through the call stack.
 *
 * Raise one with `toastManager.add({ type: 'success', title: '…' })`. Passing
 * an `id` that already exists updates that toast in place and restarts its
 * timer, which is how a long-running job reports progress through a single
 * toast rather than stacking one per step.
 */
export const toastManager = ToastPrimitive.createToastManager()

const ICONS: Record<string, React.ReactNode> = {
  success: <CircleCheckIcon className="text-emerald-600 dark:text-emerald-400" />,
  error: <OctagonXIcon className="text-destructive" />,
  warning: <TriangleAlertIcon className="text-amber-600 dark:text-amber-400" />,
  info: <InfoIcon className="text-muted-foreground" />,
  loading: <Loader2Icon className="animate-spin text-muted-foreground" />,
}

function ToastViewport({ className, ...props }: ToastPrimitive.Viewport.Props) {
  return (
    <ToastPrimitive.Viewport
      data-slot="toast-viewport"
      className={cn(
        // `z-40`, below the overlay layer (`z-50`) rather than above
        // everything: the stack sits bottom-right, which is exactly where a
        // side sheet's footer buttons are, and a toast drifting over Save is
        // both unclickable and a click the merchant did not intend.
        'pointer-events-none fixed inset-x-4 bottom-[max(1rem,env(safe-area-inset-bottom))] z-40 mx-auto w-auto max-w-sm outline-none sm:right-4 sm:left-auto sm:mx-0 sm:w-full',
        className,
      )}
      {...props}
    />
  )
}

function Toast({ className, ...props }: ToastPrimitive.Root.Props) {
  return (
    <ToastPrimitive.Root
      data-slot="toast"
      className={cn(
        'group/toast pointer-events-auto absolute right-0 bottom-0 z-[calc(1000-var(--toast-index))] w-full origin-bottom rounded-2xl border bg-popover text-popover-foreground shadow-lg will-change-transform outline-none select-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50',
        '[--gap:0.75rem] [--height:var(--toast-frontmost-height,var(--toast-height))] [--offset-y:calc(var(--toast-offset-y)*-1+calc(var(--toast-index)*var(--gap)*-1)+var(--toast-swipe-movement-y))] [--peek:0.75rem] [--scale:calc(max(0,1-(var(--toast-index)*0.1)))] [--shrink:calc(1-var(--scale))]',
        'h-(--height) [transform:translateX(var(--toast-swipe-movement-x))_translateY(calc(var(--toast-swipe-movement-y)-(var(--toast-index)*var(--peek))-(var(--shrink)*var(--height))))_scale(var(--scale))] [transition:transform_500ms_cubic-bezier(0.22,1,0.36,1),opacity_500ms,height_150ms]',
        "after:absolute after:top-full after:left-0 after:h-[calc(var(--gap)+1px)] after:w-full after:content-['']",
        'data-expanded:h-(--toast-height) data-expanded:[transform:translateX(var(--toast-swipe-movement-x))_translateY(var(--offset-y))]',
        'data-limited:opacity-0 data-starting-style:[transform:translateY(150%)]',
        '[&[data-ending-style]:not([data-limited]):not([data-swipe-direction])]:[transform:translateY(150%)]',
        'data-ending-style:data-[swipe-direction=down]:[transform:translateY(calc(var(--toast-swipe-movement-y)+150%))]',
        'data-ending-style:data-[swipe-direction=left]:[transform:translateX(calc(var(--toast-swipe-movement-x)-150%))_translateY(var(--offset-y))]',
        'data-ending-style:data-[swipe-direction=right]:[transform:translateX(calc(var(--toast-swipe-movement-x)+150%))_translateY(var(--offset-y))]',
        'data-ending-style:data-[swipe-direction=up]:[transform:translateY(calc(var(--toast-swipe-movement-y)-150%))]',
        'data-expanded:data-ending-style:data-[swipe-direction=down]:[transform:translateY(calc(var(--toast-swipe-movement-y)+150%))]',
        'data-expanded:data-ending-style:data-[swipe-direction=left]:[transform:translateX(calc(var(--toast-swipe-movement-x)-150%))_translateY(var(--offset-y))]',
        'data-expanded:data-ending-style:data-[swipe-direction=right]:[transform:translateX(calc(var(--toast-swipe-movement-x)+150%))_translateY(var(--offset-y))]',
        'data-expanded:data-ending-style:data-[swipe-direction=up]:[transform:translateY(calc(var(--toast-swipe-movement-y)-150%))]',
        className,
      )}
      {...props}
    />
  )
}

function ToastContent({ className, ...props }: ToastPrimitive.Content.Props) {
  return (
    <ToastPrimitive.Content
      data-slot="toast-content"
      className={cn(
        'flex items-center gap-3 overflow-hidden p-4 transition-opacity duration-250 ease-[cubic-bezier(0.22,1,0.36,1)] data-behind:opacity-0 data-expanded:opacity-100',
        className,
      )}
      {...props}
    />
  )
}

function ToastIcon({ type }: { type: string | undefined }) {
  const icon = type ? ICONS[type] : null
  if (!icon) return null

  return (
    <span
      data-slot="toast-icon"
      className="shrink-0 [&_svg]:pointer-events-none [&_svg:not([class*='size-'])]:size-4"
    >
      {icon}
    </span>
  )
}

function ToastList() {
  const { toasts } = ToastPrimitive.useToastManager()

  return toasts.map((toast) => (
    <Toast
      key={toast.id}
      toast={toast}
      // Base UI types a toast as `dialog`, which puts every transient
      // notification in the same bucket as real modals — a `getByRole('dialog')`
      // lookup, ours or a screen reader user's, matches whatever toast happens
      // to be on screen. `status` is what a passive notification should expose.
      role={toast.type === 'error' ? 'alert' : 'status'}
    >
      <ToastContent>
        <ToastIcon type={toast.type} />
        <div className="flex min-w-0 flex-1 flex-col gap-1">
          <ToastPrimitive.Title data-slot="toast-title" className="font-medium text-sm" />
          <ToastPrimitive.Description
            data-slot="toast-description"
            className="text-muted-foreground text-sm"
          />
        </div>
        <ToastPrimitive.Action
          data-slot="toast-action"
          render={<Button variant="outline" size="sm" />}
          className="shrink-0"
        />
        <ToastPrimitive.Close
          data-slot="toast-close"
          aria-label={i18n.t('admin.actions.close')}
          render={<Button variant="ghost" size="icon-sm" />}
          className="relative shrink-0 text-muted-foreground after:absolute after:-inset-2 after:content-[''] hover:text-foreground"
        >
          <XIcon aria-hidden="true" />
        </ToastPrimitive.Close>
      </ToastContent>
    </Toast>
  ))
}

/**
 * Mount once at the app root, inside the provider that owns the queue.
 *
 * Replaces the Sonner toaster: shadcn dropped that integration in favour of
 * this Base UI primitive, which is also what every other overlay in this app
 * (Sheet, Dialog, Popover, Select) is already built on.
 */
export function Toaster({ children }: { children?: React.ReactNode }) {
  return (
    <ToastPrimitive.Provider toastManager={toastManager}>
      {children}
      <ToastPrimitive.Portal data-slot="toast-portal">
        <ToastViewport>
          <ToastList />
        </ToastViewport>
      </ToastPrimitive.Portal>
    </ToastPrimitive.Provider>
  )
}
