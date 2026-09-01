import type * as React from 'react'
import { useRef } from 'react'
import { cn } from '../lib/utils'
import { InputGroup, InputGroupAddon, InputGroupButton, InputGroupInput } from '../ui/input-group'
import { SearchIcon, XIcon } from './icons'

/**
 * Search box with a leading magnifier and our own clear button.
 *
 * The clear button is hand-rolled rather than `type="search"`'s native one:
 * that control is unstyleable, ignores the design tokens, renders at a size no
 * touch guideline would accept, and Safari on iOS omits it entirely — so on a
 * phone the field could not be cleared at all. The input stays `type="text"`
 * to keep the native affordance from rendering alongside this one, and carries
 * `role="searchbox"` so it still announces as a search field — the role a
 * `type="search"` input would have given it for free.
 *
 * Clearing returns focus to the field, since the user is almost always about
 * to type a different query.
 */
export function SearchInput({
  value,
  onValueChange,
  className,
  clearLabel = 'Clear search',
  ...props
}: Omit<React.ComponentProps<'input'>, 'value' | 'onChange' | 'type' | 'className'> & {
  value: string
  onValueChange: (value: string) => void
  /** Sizing and surface for the whole field. The input fills it. */
  className?: string
  /** Accessible name for the clear button. */
  clearLabel?: string
}) {
  const inputRef = useRef<HTMLInputElement>(null)

  return (
    <InputGroup className={className}>
      <InputGroupAddon>
        <SearchIcon className="size-4" />
      </InputGroupAddon>
      {/* `h-full` so callers size the field once, on the wrapper, rather than
          repeating the same height rule on both. */}
      <InputGroupInput
        ref={inputRef}
        type="text"
        role="searchbox"
        value={value}
        onChange={(event) => onValueChange(event.target.value)}
        className="h-full"
        {...props}
      />
      {value && (
        <InputGroupAddon align="inline-end">
          <InputGroupButton
            // `icon-sm` rather than the default `xs`: that variant hardcodes
            // `h-6`, which tailwind-merge cannot reconcile against a `size-*`
            // override, so the button would stay 24px however it was classed.
            size="icon-sm"
            aria-label={clearLabel}
            onClick={() => {
              onValueChange('')
              inputRef.current?.focus()
            }}
            // Touch-sized by default and only compact from `md` up, so a phone
            // always gets the larger target whether or not the field happens to
            // sit inside the mobile drawer. The glyph stays small either way.
            className={cn('size-9 rounded-full md:size-6 in-data-[mobile=true]:size-9')}
          >
            <XIcon className="size-4" />
          </InputGroupButton>
        </InputGroupAddon>
      )}
    </InputGroup>
  )
}
