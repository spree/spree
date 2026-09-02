import { Accordion as AccordionPrimitive } from '@base-ui/react/accordion'
import type * as React from 'react'
import { cn } from '../lib/utils'
import { ChevronDownIcon } from '../spree/icons'

/**
 * Vertically stacked, expandable sections sharing one frame.
 *
 * One item is open at a time by default: a list of steps is read in order, and
 * letting several stand open turns it back into the wall of text the collapse
 * exists to avoid. Pass `multiple` where the sections are independent rather
 * than sequential.
 */
function Accordion({ ...props }: React.ComponentProps<typeof AccordionPrimitive.Root>) {
  return <AccordionPrimitive.Root data-slot="accordion" {...props} />
}

/** One section. `value` identifies it for `defaultValue` and controlled use. */
function AccordionItem({
  className,
  ...props
}: React.ComponentProps<typeof AccordionPrimitive.Item>) {
  return (
    <AccordionPrimitive.Item
      data-slot="accordion-item"
      // Rules between items rather than around each: the group is one object,
      // so the last item closes on the container's own edge.
      className={cn('border-border-subtle border-b last:border-b-0', className)}
      {...props}
    />
  )
}

/**
 * The always-visible row that opens its section. Renders a chevron after the
 * children, so callers pass only the label's own content.
 */
function AccordionTrigger({
  className,
  children,
  ...props
}: React.ComponentProps<typeof AccordionPrimitive.Trigger>) {
  return (
    <AccordionPrimitive.Header className="flex">
      <AccordionPrimitive.Trigger
        data-slot="accordion-trigger"
        className={cn(
          'group/accordion-trigger flex flex-1 cursor-pointer items-center gap-3 px-4 py-3.5 text-left text-base font-medium transition-colors outline-none hover:bg-accent/50 focus-visible:bg-accent',
          className,
        )}
        {...props}
      >
        {children}
        <ChevronDownIcon className="ms-auto size-4 shrink-0 text-muted-foreground transition-transform duration-200 ease-out group-data-[panel-open]/accordion-trigger:rotate-180 motion-reduce:transition-none" />
      </AccordionPrimitive.Trigger>
    </AccordionPrimitive.Header>
  )
}

/**
 * The revealed panel. Carries the section's padding, so `className` styles the
 * content rather than the animated box around it.
 */
function AccordionContent({
  className,
  children,
  ...props
}: React.ComponentProps<typeof AccordionPrimitive.Panel>) {
  return (
    <AccordionPrimitive.Panel
      data-slot="accordion-content"
      // Height animates off Base UI's own `--accordion-panel-height`, which it
      // measures for us — `height: auto` is not animatable, so without the
      // variable the panel would snap open.
      className="h-(--accordion-panel-height) overflow-hidden transition-[height] duration-200 ease-out data-[ending-style]:h-0 data-[starting-style]:h-0 motion-reduce:transition-none"
      {...props}
    >
      <div className={cn('px-4 pb-4', className)}>{children}</div>
    </AccordionPrimitive.Panel>
  )
}

export { Accordion, AccordionContent, AccordionItem, AccordionTrigger }
