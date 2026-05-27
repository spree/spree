import * as React from 'react'
import { cn } from '@/lib/utils'

/**
 * A simple Slot component that merges props onto its single child element.
 * This replaces the Radix UI `Slot` primitive for `asChild`-style composition.
 */
function Slot({
  children,
  ...props
}: React.HTMLAttributes<HTMLElement> & { children?: React.ReactNode }) {
  if (React.isValidElement(children)) {
    const childProps = children.props as Record<string, unknown>
    return React.cloneElement(children, {
      ...props,
      ...childProps,
      className: cn(
        (props as Record<string, unknown>).className as string | undefined,
        childProps.className as string | undefined,
      ),
      style: {
        ...((props as Record<string, unknown>).style as React.CSSProperties | undefined),
        ...(childProps.style as React.CSSProperties | undefined),
      },
    } as React.HTMLAttributes<HTMLElement>)
  }

  if (React.Children.count(children) > 1) {
    React.Children.only(null)
  }

  return null
}

export { Slot }
