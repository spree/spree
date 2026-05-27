import { Checkbox as CheckboxPrimitive } from '@base-ui/react/checkbox'
import { CheckIcon, MinusIcon } from 'lucide-react'
import type * as React from 'react'
import { cn } from '../lib/utils'

function Checkbox({
  className,
  checked,
  defaultChecked,
  onCheckedChange,
  indeterminate,
  disabled,
  name,
  ...props
}: Omit<React.ComponentProps<typeof CheckboxPrimitive.Root>, 'children' | 'onCheckedChange'> & {
  onCheckedChange?: (checked: boolean) => void
}) {
  return (
    <CheckboxPrimitive.Root
      data-slot="checkbox"
      checked={checked}
      defaultChecked={defaultChecked}
      onCheckedChange={onCheckedChange ? (next) => onCheckedChange(next) : undefined}
      indeterminate={indeterminate}
      disabled={disabled}
      name={name}
      className={cn(
        'peer relative inline-block size-4 shrink-0 rounded-[4px] border border-input align-[-3px] shadow-xs outline-none transition-shadow',
        'focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50',
        'disabled:cursor-not-allowed disabled:opacity-50',
        'aria-invalid:border-destructive aria-invalid:ring-destructive/20',
        'data-[checked]:border-primary data-[checked]:bg-primary data-[checked]:text-primary-foreground',
        'data-[indeterminate]:border-primary data-[indeterminate]:bg-primary data-[indeterminate]:text-primary-foreground',
        'dark:bg-input/30 dark:aria-invalid:ring-destructive/40 dark:data-[checked]:bg-primary',
        className,
      )}
      {...props}
    >
      <CheckboxPrimitive.Indicator
        keepMounted
        data-slot="checkbox-indicator"
        className="absolute inset-0 flex items-center justify-center text-current transition-none data-[unchecked]:hidden"
      >
        {indeterminate ? <MinusIcon className="size-3.5" /> : <CheckIcon className="size-3.5" />}
      </CheckboxPrimitive.Indicator>
    </CheckboxPrimitive.Root>
  )
}

export { Checkbox }
