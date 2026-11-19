import * as React from 'react'

import { cn } from '../lib/utils'
import { ChevronDownIcon, ChevronUpIcon } from '../spree/icons'

const FIELD_BOX =
  'rounded-xl border border-field-border shadow-control bg-card transition-[color,background-color,border-color,box-shadow] duration-100 ease-out'

function Input({
  className,
  type,
  stepper,
  ...props
}: React.ComponentProps<'input'> & {
  /** `false` keeps a number field plain, where a column has no room for the buttons. */
  stepper?: boolean
}) {
  if (type === 'number' && stepper !== false)
    return <NumberInput className={className} {...props} />

  return (
    <input
      type={type}
      data-slot="input"
      className={cn(
        FIELD_BOX,
        'block w-full min-w-0 min-h-8 cursor-default focus:cursor-text py-1.5 [appearance:textfield] [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:appearance-none px-2.5 text-base font-normal leading-normal text-foreground outline-none placeholder:text-muted-foreground not-disabled:not-read-only:not-focus:hover:bg-field-hover focus:border-blue-500 focus:shadow-field-focus disabled:cursor-not-allowed disabled:bg-muted disabled:text-muted-foreground aria-invalid:border-destructive file:inline-flex file:h-6 file:border-0 file:bg-transparent file:text-base file:font-medium file:text-foreground',
        className,
      )}
      {...props}
    />
  )
}

// The two buttons stack into one pill 3px inside the field's edge. Its outer
// corners follow the field's (radius-xl, less the 1px border and the 3px gap),
// so the curves stay parallel; the corners where the buttons meet stay tight.
const STEP_RADIUS_UP = 'rounded-t-[calc(var(--radius-xl)-4px)] rounded-b-[2px]'
const STEP_RADIUS_DOWN = 'rounded-b-[calc(var(--radius-xl)-4px)] rounded-t-[2px]'

type NumberInputProps = Omit<React.ComponentProps<'input'>, 'type'> & {
  /** Drops the field's own box, for an input that sits inside an `InputGroup`. */
  bare?: boolean
}

/**
 * A number field with increase and decrease buttons. Every `<Input
 * type="number">` renders this, so forms get it without opting in.
 *
 * `className` lands on the outer box, so width, margin and border classes
 * work as they do on a plain input; text alignment and numeral style carry
 * through to the value. The buttons are skipped by Tab — the arrow keys
 * already step the value.
 */
function NumberInput({ className, bare, disabled, readOnly, ref, ...props }: NumberInputProps) {
  const inputRef = React.useRef<HTMLInputElement>(null)
  // A form library passes its own ref; the buttons need the element too.
  const setRef = (node: HTMLInputElement | null) => {
    inputRef.current = node
    if (typeof ref === 'function') ref(node)
    else if (ref) ref.current = node
  }
  const repeat = React.useRef<ReturnType<typeof setTimeout> | null>(null)
  const interactive = !disabled && !readOnly

  const step = (direction: 1 | -1) => {
    const input = inputRef.current
    if (!input) return
    try {
      direction === 1 ? input.stepUp() : input.stepDown()
    } catch {
      // `step="any"` has no step to take; move by one, inside min and max.
      let next = (Number.parseFloat(input.value) || 0) + direction
      if (input.min !== '') next = Math.max(next, Number(input.min))
      if (input.max !== '') next = Math.min(next, Number(input.max))
      Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')?.set?.call(
        input,
        String(next),
      )
    }
    // The value changed outside React, so announce it the way typing would.
    input.dispatchEvent(new Event('input', { bubbles: true }))
    input.dispatchEvent(new Event('change', { bubbles: true }))
  }

  const stopRepeat = () => {
    if (repeat.current) clearTimeout(repeat.current)
    repeat.current = null
  }

  // Holding a button keeps stepping, slowly at first.
  const startRepeat = (direction: 1 | -1) => (event: React.PointerEvent) => {
    if (event.button !== 0) return
    event.preventDefault()
    inputRef.current?.focus()
    step(direction)
    const tick = (delay: number) => {
      repeat.current = setTimeout(() => {
        step(direction)
        tick(60)
      }, delay)
    }
    tick(400)
  }

  React.useEffect(() => stopRepeat, [])

  const button = (direction: 1 | -1) => (
    <button
      type="button"
      tabIndex={-1}
      aria-hidden
      disabled={!interactive}
      onPointerDown={startRepeat(direction)}
      onPointerUp={stopRepeat}
      onPointerLeave={stopRepeat}
      onPointerCancel={stopRepeat}
      className={cn(
        'flex flex-1 cursor-pointer items-center justify-center bg-stepper text-muted-foreground transition-colors hover:bg-stepper-hover hover:text-foreground active:bg-stepper-active active:text-foreground disabled:cursor-not-allowed [&_svg]:size-3',
        direction === 1 ? STEP_RADIUS_UP : STEP_RADIUS_DOWN,
      )}
    >
      {direction === 1 ? (
        <ChevronUpIcon strokeWidth={2.5} />
      ) : (
        <ChevronDownIcon strokeWidth={2.5} />
      )}
    </button>
  )

  return (
    <span
      data-slot="number-field"
      className={cn(
        'relative flex w-full min-w-0 items-stretch text-foreground',
        !bare &&
          cn(
            FIELD_BOX,
            'min-h-8 not-has-[input:disabled]:not-has-[input:read-only]:not-focus-within:hover:bg-field-hover focus-within:border-blue-500 focus-within:shadow-field-focus has-[input:disabled]:cursor-not-allowed has-[input:disabled]:bg-muted has-[input:disabled]:text-muted-foreground has-aria-invalid:border-destructive',
          ),
        className,
      )}
    >
      <input
        ref={setRef}
        type="number"
        data-slot="input"
        disabled={disabled}
        readOnly={readOnly}
        {...props}
        className="block w-full min-w-0 flex-1 cursor-default focus:cursor-text appearance-none bg-transparent py-1.5 pl-2.5 pr-1 text-base font-normal leading-normal text-inherit [font-variant-numeric:inherit] [text-align:inherit] outline-none placeholder:text-muted-foreground disabled:cursor-not-allowed [appearance:textfield] [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:appearance-none"
      />
      {interactive && (
        <span className="flex w-6 shrink-0 flex-col gap-px py-[3px] pr-[3px]">
          {button(1)}
          {button(-1)}
        </span>
      )}
    </span>
  )
}

export { Input, NumberInput }
