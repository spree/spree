'use client'

import { mergeProps } from '@base-ui/react/merge-props'
import { useRender } from '@base-ui/react/use-render'
import { cva, type VariantProps } from 'class-variance-authority'
import type * as React from 'react'

import { cn } from '../lib/utils'
import { Button } from './button'

// Ported from the shadcn Base UI `attachment` registry component, with the
// `cn-*` preset classes flattened into plain utilities (this package predates
// the shadcn CSS layer).
const attachmentVariants = cva(
  'group/attachment relative flex max-w-full min-w-0 shrink-0 flex-wrap rounded-lg border bg-card text-card-foreground transition-colors has-[>a,>button]:hover:bg-muted/50 data-[state=error]:border-destructive/30 data-[state=idle]:border-dashed',
  {
    variants: {
      size: {
        default: 'gap-2.5 p-2 pr-2.5',
        sm: 'gap-2 p-1.5 pr-2',
        xs: 'gap-1.5 p-1 pr-1.5',
      },
      orientation: {
        horizontal: 'items-center',
        vertical: 'flex-col',
      },
    },
  },
)

function Attachment({
  className,
  state = 'done',
  size = 'default',
  orientation = 'horizontal',
  ...props
}: React.ComponentProps<'div'> &
  VariantProps<typeof attachmentVariants> & {
    state?: 'idle' | 'uploading' | 'processing' | 'error' | 'done'
  }) {
  return (
    <div
      data-slot="attachment"
      data-state={state}
      data-size={size}
      data-orientation={orientation}
      className={cn(attachmentVariants({ size, orientation }), className)}
      {...props}
    />
  )
}

const attachmentMediaVariants = cva(
  'relative flex aspect-square size-9 shrink-0 items-center justify-center overflow-hidden rounded-md group-data-[state=error]/attachment:bg-destructive/10 group-data-[state=error]/attachment:text-destructive [&_svg]:pointer-events-none [&_svg:not([class*=size-])]:size-4',
  {
    variants: {
      variant: {
        icon: 'bg-muted text-muted-foreground',
        // Image fit is left to the caller's <img> classes — logos want
        // `object-contain`, photos want `object-cover`.
        image: 'bg-muted',
      },
    },
    defaultVariants: {
      variant: 'icon',
    },
  },
)

function AttachmentMedia({
  className,
  variant = 'icon',
  ...props
}: React.ComponentProps<'div'> & VariantProps<typeof attachmentMediaVariants>) {
  return (
    <div
      data-slot="attachment-media"
      data-variant={variant}
      className={cn(attachmentMediaVariants({ variant }), className)}
      {...props}
    />
  )
}

function AttachmentContent({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="attachment-content"
      className={cn('max-w-full min-w-0 flex-1', className)}
      {...props}
    />
  )
}

function AttachmentTitle({ className, ...props }: React.ComponentProps<'span'>) {
  return (
    <span
      data-slot="attachment-title"
      className={cn('block max-w-full min-w-0 truncate font-medium text-sm', className)}
      {...props}
    />
  )
}

function AttachmentDescription({ className, ...props }: React.ComponentProps<'span'>) {
  return (
    <span
      data-slot="attachment-description"
      className={cn(
        'block max-w-full min-w-0 truncate text-muted-foreground text-xs group-data-[state=error]/attachment:text-destructive/80',
        className,
      )}
      {...props}
    />
  )
}

function AttachmentActions({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="attachment-actions"
      className={cn('flex shrink-0 items-center gap-1', className)}
      {...props}
    />
  )
}

function AttachmentAction({
  className,
  variant,
  size = 'icon-xs',
  ...props
}: React.ComponentProps<typeof Button>) {
  return (
    <Button
      data-slot="attachment-action"
      variant={variant ?? 'ghost'}
      size={size}
      className={className}
      {...props}
    />
  )
}

function AttachmentTrigger({
  className,
  render,
  type,
  ...props
}: useRender.ComponentProps<'button'>) {
  return useRender({
    defaultTagName: 'button',
    props: mergeProps<'button'>(
      {
        type: render ? type : (type ?? 'button'),
        className: cn('absolute inset-0 z-10 outline-none', className),
      },
      props,
    ),
    render,
    state: {
      slot: 'attachment-trigger',
    },
  })
}

function AttachmentGroup({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="attachment-group"
      className={cn('flex min-w-0 gap-2 overflow-x-auto', className)}
      {...props}
    />
  )
}

export {
  Attachment,
  AttachmentAction,
  AttachmentActions,
  AttachmentContent,
  AttachmentDescription,
  AttachmentGroup,
  AttachmentMedia,
  AttachmentTitle,
  AttachmentTrigger,
}
