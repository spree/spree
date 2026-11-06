import { Switch as SwitchPrimitive } from '@base-ui/react/switch'
import type * as React from 'react'
import { cn } from '../lib/utils'

function Switch({
  className,
  checked,
  defaultChecked,
  onCheckedChange,
  disabled,
  name,
  ...props
}: Omit<React.ComponentProps<typeof SwitchPrimitive.Root>, 'children'> & {
  onCheckedChange?: (checked: boolean) => void
}) {
  return (
    <SwitchPrimitive.Root
      data-slot="switch"
      checked={checked}
      defaultChecked={defaultChecked}
      onCheckedChange={onCheckedChange ? (checked) => onCheckedChange(checked) : undefined}
      disabled={disabled}
      name={name}
      className={cn(
        // iOS proportions at a desk-sized 33×18: a pill with a knob that
        // fills its height.
        // Base UI renders a <span>, which is never `:disabled`, so disabled
        // styles key off `data-disabled`. The off track is a mid-grey rather
        // than the input tint, which sat at 1.2:1 and left the knob visible
        // only by its shadow.
        'group/switch peer inline-flex h-[18px] w-[33px] shrink-0 cursor-pointer items-center rounded-full border-2 border-transparent transition-[background-color,box-shadow] duration-200 ease-out outline-none focus-visible:shadow-field-focus data-[checked]:bg-blue-500 data-[unchecked]:bg-switch-off data-[disabled]:cursor-not-allowed data-[disabled]:opacity-50',
        className,
      )}
      {...props}
    >
      <SwitchPrimitive.Thumb
        className={cn(
          // A layered shadow lifts the knob off the track, and the slide
          // overshoots a touch before settling. While pressed the knob
          // stretches toward the middle, as iOS does, and a checked knob
          // shifts left by the stretch so its right edge stays put.
          'pointer-events-none block size-3.5 rounded-full bg-white shadow-[0_2px_6px_rgb(0_0_0/0.15),0_2px_1px_rgb(0_0_0/0.06),0_0_0_0.5px_rgb(0_0_0/0.04)] transition-[translate,width] duration-200 ease-[cubic-bezier(0.34,1.36,0.64,1)] motion-reduce:transition-none data-[checked]:translate-x-[15px] data-[unchecked]:translate-x-0 group-active/switch:w-[18px] data-[checked]:group-active/switch:translate-x-[11px]',
        )}
      />
    </SwitchPrimitive.Root>
  )
}

export { Switch }
