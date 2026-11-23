import { Collapsible as CollapsiblePrimitive } from '@base-ui/react/collapsible'
import type * as React from 'react'
import { cn } from '../lib/utils'

function Collapsible({ ...props }: React.ComponentProps<typeof CollapsiblePrimitive.Root>) {
  return <CollapsiblePrimitive.Root data-slot="collapsible" {...props} />
}

function CollapsibleTrigger({
  ...props
}: React.ComponentProps<typeof CollapsiblePrimitive.Trigger>) {
  return <CollapsiblePrimitive.Trigger data-slot="collapsible-trigger" {...props} />
}

/**
 * Opens and closes by sliding its height, which Base UI measures into
 * `--collapsible-panel-height`, and fading so rows aren't sliced by the
 * moving edge. Same timing as the chevrons that toggle it. Instant under
 * reduced motion.
 */
function CollapsibleContent({
  className,
  ...props
}: React.ComponentProps<typeof CollapsiblePrimitive.Panel>) {
  return (
    <CollapsiblePrimitive.Panel
      data-slot="collapsible-content"
      className={cn(
        'h-[var(--collapsible-panel-height)] overflow-hidden transition-[height,opacity] duration-200 ease-out data-[ending-style]:h-0 data-[ending-style]:opacity-0 data-[starting-style]:h-0 data-[starting-style]:opacity-0 motion-reduce:transition-none',
        className,
      )}
      {...props}
    />
  )
}

export { Collapsible, CollapsibleContent, CollapsibleTrigger }
