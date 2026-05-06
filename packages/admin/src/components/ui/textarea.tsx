import * as React from 'react'

import { cn } from '@/lib/utils'

function Textarea({ className, ...props }: React.ComponentProps<'textarea'>) {
  return (
    <textarea
      data-slot="textarea"
      className={cn(
        'flex field-sizing-content min-h-16 w-full rounded-lg border border-border bg-card px-2.5 py-1.5 text-base font-normal leading-normal text-foreground shadow-xs transition-all duration-100 ease-in-out outline-none placeholder:text-muted-foreground focus:border-blue-500 focus:shadow-[0_0_0_3px_rgba(59,130,246,0.15)] disabled:pointer-events-none disabled:cursor-not-allowed disabled:bg-muted disabled:border-border disabled:text-muted-foreground disabled:shadow-none aria-invalid:border-destructive',
        className,
      )}
      {...props}
    />
  )
}

export { Textarea }
