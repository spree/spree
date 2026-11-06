import * as React from 'react'

import { cn } from '../lib/utils'

function Textarea({ className, ...props }: React.ComponentProps<'textarea'>) {
  return (
    <textarea
      data-slot="textarea"
      className={cn(
        'flex field-sizing-content min-h-16 w-full rounded-lg border border-field-border shadow-control bg-card px-2.5 py-1.5 text-base font-normal leading-normal text-foreground transition-[color,background-color,border-color,box-shadow] duration-100 ease-out outline-none placeholder:text-muted-foreground focus:border-blue-500 focus:shadow-field-focus disabled:cursor-not-allowed disabled:bg-muted disabled:text-muted-foreground aria-invalid:border-destructive',
        className,
      )}
      {...props}
    />
  )
}

export { Textarea }
