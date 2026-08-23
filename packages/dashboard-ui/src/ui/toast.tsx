'use client'

import { Toast as ToastPrimitive } from '@base-ui/react/toast'
import i18n from 'i18next'
import {
  CircleCheckIcon,
  InfoIcon,
  Loader2Icon,
  OctagonXIcon,
  TriangleAlertIcon,
  XIcon,
} from 'lucide-react'
import type * as React from 'react'
import { cn } from '../lib/utils'

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
  success: <CircleCheckIcon className="size-4 text-emerald-600 dark:text-emerald-400" />,
  error: <OctagonXIcon className="size-4 text-destructive" />,
  warning: <TriangleAlertIcon className="size-4 text-amber-600 dark:text-amber-400" />,
  info: <InfoIcon className="size-4 text-muted-foreground" />,
  loading: <Loader2Icon className="size-4 animate-spin text-muted-foreground" />,
}

function ToastList() {
  const { toasts } = ToastPrimitive.useToastManager()

  return toasts.map((toast) => (
    <ToastPrimitive.Root
      key={toast.id}
      toast={toast}
      // `--toast-index` / `--toast-offset-y` drive the stacked-card effect:
      // toasts behind the front one scale down and sit slightly higher.
      className={cn(
        // Normal flow inside a bottom-anchored column, not absolute
        // positioning: a zero-height viewport gives an absolutely-positioned
        // child nothing to sit on, and it renders below the fold.
        'pointer-events-auto w-full',
        'rounded-xl border border-border bg-popover p-4 text-popover-foreground shadow-lg',
        'transition-all duration-200 ease-out',
        'data-[starting-style]:translate-y-2 data-[starting-style]:opacity-0',
        'data-[ending-style]:translate-y-2 data-[ending-style]:opacity-0',
      )}
    >
      <div className="flex items-start gap-3">
        {toast.type && ICONS[toast.type] && (
          <span className="mt-0.5 shrink-0">{ICONS[toast.type]}</span>
        )}
        <div className="flex min-w-0 flex-1 flex-col gap-1">
          <ToastPrimitive.Title className="font-medium text-sm leading-snug" />
          <ToastPrimitive.Description className="text-muted-foreground text-sm leading-snug" />
        </div>
        <ToastPrimitive.Close
          // 44px tap target on touch, compact for a pointer — the same rule the
          // rest of the app follows for icon-only controls.
          className="-mt-1 -mr-1 inline-flex size-7 shrink-0 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
          aria-label={i18n.t('admin.actions.close')}
        >
          <XIcon className="size-4" />
        </ToastPrimitive.Close>
      </div>
    </ToastPrimitive.Root>
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
      <ToastPrimitive.Portal>
        <ToastPrimitive.Viewport
          className={cn(
            'fixed right-4 z-[1000] flex w-[min(22rem,calc(100vw-2rem))] flex-col gap-2',
            // `pointer-events-none` on the column so the empty space above the
            // stack never blocks the page; each toast takes them back.
            'pointer-events-none',
            'bottom-[max(1rem,env(safe-area-inset-bottom))]',
          )}
        >
          <ToastList />
        </ToastPrimitive.Viewport>
      </ToastPrimitive.Portal>
    </ToastPrimitive.Provider>
  )
}
