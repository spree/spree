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
        // A flat track with a hairline edge instead of depth, and a capsule
        // knob wider than it is tall, after the macOS switch.
        // Base UI renders a <span>, which is never `:disabled`, so disabled
        // styles key off `data-disabled`.
        'group/switch peer inline-flex h-[18px] w-[34px] shrink-0 cursor-pointer items-center rounded-full p-0.5 shadow-[inset_0_0_0_0.5px_rgb(0_0_0/0.08)] transition-[background-color,box-shadow] duration-200 ease-out outline-none focus-visible:shadow-field-focus data-[checked]:bg-blue-500 data-[unchecked]:bg-switch-off data-[disabled]:cursor-not-allowed data-[disabled]:opacity-50',
        className,
      )}
      {...props}
    >
      <SwitchPrimitive.Thumb
        className={cn(
          // While pressed the knob turns to glass: it grows, clears to a
          // frosted tint over the track, and keeps a bright rim.
          'pointer-events-none block h-3.5 w-5 rounded-full bg-white shadow-[0_0_0_0.5px_rgb(0_0_0/0.06),0_1px_2px_rgb(0_0_0/0.1)] transition-[translate,scale,background-color,box-shadow] duration-200 ease-[cubic-bezier(0.3,1.3,0.6,1)] motion-reduce:transition-none data-[checked]:translate-x-2.5 data-[unchecked]:translate-x-0 group-active/switch:scale-x-[1.3] group-active/switch:scale-y-[1.2] group-active/switch:bg-white/35 group-active/switch:shadow-[inset_0_0_0_1px_rgb(255_255_255/0.85),0_1px_4px_rgb(0_0_0/0.15)] group-active/switch:backdrop-blur-[2px] group-data-[disabled]/switch:scale-100 group-data-[disabled]/switch:bg-white',
        )}
      />
    </SwitchPrimitive.Root>
  )
}

export { Switch }
