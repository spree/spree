import { Field } from '@base-ui/react/field'
import * as React from 'react'

import { cn } from '@/lib/utils'

/**
 * Label component backed by Base UI's Field.Label.
 *
 * Wraps each label in a Field.Root so it can be used standalone
 * without requiring consumers to manually add Field.Root parents.
 */
function Label({ className, children, ...props }: React.ComponentProps<'label'>) {
  return (
    <Field.Root>
      <Field.Label
        data-slot="label"
        className={cn(
          'flex items-center gap-2 text-sm leading-none font-medium select-none group-data-[disabled=true]:pointer-events-none group-data-[disabled=true]:opacity-50 peer-disabled:cursor-not-allowed peer-disabled:opacity-50',
          className,
        )}
        {...props}
      >
        {children}
      </Field.Label>
    </Field.Root>
  )
}

export { Label }
