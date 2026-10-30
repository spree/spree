import { Autocomplete as AutocompletePrimitive } from '@base-ui/react'
import i18n from 'i18next'
import * as React from 'react'
import { cn } from '../lib/utils'
import {
  CheckIcon,
  CornerDownLeftIcon,
  Loader2Icon,
  MoveDownIcon,
  MoveUpIcon,
  SearchIcon,
} from '../spree/icons'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from './dialog'

type CommandInputBinding = { value?: string; onValueChange?: (value: string) => void }

const CommandContext = React.createContext<{
  query: string
  shouldFilter: boolean
  bindInput: (binding: CommandInputBinding) => void
}>({ query: '', shouldFilter: false, bindInput: () => {} })

/**
 * A search field over a list of actions, on Base UI's Autocomplete rendered
 * inline. The query lives on `CommandInput`. Rows whose `value` or text does not
 * contain the query are hidden unless `shouldFilter` is false.
 */
function Command({
  className,
  children,
  shouldFilter = true,
  ...props
}: React.ComponentProps<'div'> & { shouldFilter?: boolean }) {
  const [input, bindInput] = React.useState<CommandInputBinding>({})
  const [query, setQuery] = React.useState('')

  // A controlled `CommandInput` can change the query from outside, such as a reset.
  React.useLayoutEffect(() => {
    if (input.value !== undefined) setQuery(input.value)
  }, [input.value])

  const context = React.useMemo(() => ({ query, shouldFilter, bindInput }), [query, shouldFilter])

  return (
    <AutocompletePrimitive.Root
      inline
      open
      autoHighlight="always"
      keepHighlight
      filter={null}
      value={query}
      onValueChange={(next, eventDetails) => {
        // Choosing a row would otherwise write that row's value into the field.
        if (eventDetails.reason === 'item-press') return
        setQuery(next)
        input.onValueChange?.(next)
      }}
      onOpenChange={(_open, eventDetails) => {
        // The list is always shown, so Escape belongs to the dialog around it.
        if (eventDetails.reason === 'escape-key') {
          eventDetails.cancel()
          eventDetails.allowPropagation()
        }
      }}
    >
      <CommandContext.Provider value={context}>
        <div
          data-slot="command"
          className={cn(
            'flex size-full flex-col overflow-hidden rounded-2xl! bg-popover text-popover-foreground',
            className,
          )}
          {...props}
        >
          {children}
        </div>
      </CommandContext.Provider>
    </AutocompletePrimitive.Root>
  )
}

function CommandDialog({
  title = i18n.t('admin.components.command_palette.title'),
  description = i18n.t('admin.components.command_palette.description'),
  children,
  className,
  showCloseButton = false,
  ...props
}: React.ComponentProps<typeof Dialog> & {
  title?: string
  description?: string
  className?: string
  showCloseButton?: boolean
}) {
  return (
    <Dialog {...props}>
      <DialogHeader className="sr-only">
        <DialogTitle>{title}</DialogTitle>
        <DialogDescription>{description}</DialogDescription>
      </DialogHeader>
      <DialogContent
        // `-translate-x-1/2` must be restated alongside `translate-y-0`: in
        // Tailwind v4 both compile to the standalone `translate` property, so
        // setting only the Y axis wipes the base dialog's horizontal centring
        // and the panel drifts off both edges of a narrow screen.
        className={cn(
          'top-1/3 -translate-x-1/2 translate-y-0 overflow-hidden rounded-xl! p-0',
          className,
        )}
        showCloseButton={showCloseButton}
      >
        {children}
      </DialogContent>
    </Dialog>
  )
}

/**
 * The palette's search field — the top edge of the panel, spanning its full
 * width above a single hairline.
 *
 * While `loading` is set, a spinner sits at the end of the field rather than in
 * the results list, so rows don't shift down when a search starts and back up
 * when it lands. The state is announced to screen readers as well as drawn.
 */
function CommandInput({
  className,
  loading = false,
  value,
  onValueChange,
  ...props
}: Omit<AutocompletePrimitive.Input.Props, 'value'> & {
  value?: string
  onValueChange?: (value: string) => void
  /** Shows a spinner at the end of the field while results are in flight. */
  loading?: boolean
}) {
  const { bindInput } = React.useContext(CommandContext)
  React.useLayoutEffect(
    () => bindInput({ value, onValueChange }),
    [bindInput, value, onValueChange],
  )

  return (
    <div
      data-slot="command-input-wrapper"
      className="flex h-14 shrink-0 items-center gap-3 border-b border-border px-5"
    >
      <SearchIcon className="size-5 shrink-0 text-muted-foreground" />
      <AutocompletePrimitive.Input
        data-slot="command-input"
        aria-busy={loading || undefined}
        className={cn(
          'h-full w-full bg-transparent text-base outline-hidden placeholder:text-muted-foreground disabled:cursor-not-allowed disabled:opacity-50',
          className,
        )}
        {...props}
      />
      {loading && (
        <Loader2Icon
          data-slot="command-input-loading"
          aria-hidden="true"
          className="size-4 shrink-0 animate-spin text-muted-foreground"
        />
      )}
      {/* The spinner is decorative, so the progress a sighted user reads from it
          is announced here instead. Polite: it must not cut off the row count
          the listbox announces when results land. */}
      <span role="status" aria-live="polite" className="sr-only">
        {loading ? i18n.t('admin.common.searching') : ''}
      </span>
    </div>
  )
}

/**
 * The results area. Its height is fixed rather than content-driven, so the
 * panel stays put as results arrive instead of resizing under the cursor on
 * every keystroke. Pass `className="h-…"` to change it, or `h-auto max-h-…`
 * for the shrink-to-fit behaviour a short static menu wants.
 */
function CommandList({ className, ...props }: AutocompletePrimitive.List.Props) {
  return (
    <AutocompletePrimitive.List
      data-slot="command-list"
      className={cn(
        'group/command-list h-80 min-h-0 scroll-py-2 overflow-x-hidden overflow-y-auto p-2 outline-none',
        className,
      )}
      {...props}
    />
  )
}

/** The message for an empty list. Hidden while the list has any rows. */
function CommandEmpty({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="command-empty"
      className={cn(
        'py-10 text-center text-sm text-muted-foreground group-has-[[data-slot=command-item]]/command-list:hidden',
        className,
      )}
      {...props}
    />
  )
}

function CommandGroup({
  className,
  heading,
  children,
  ...props
}: AutocompletePrimitive.Group.Props & { heading?: React.ReactNode }) {
  return (
    <AutocompletePrimitive.Group
      data-slot="command-group"
      className={cn(
        'overflow-hidden text-foreground not-last:pb-2 not-has-[[data-slot=command-item]]:hidden',
        className,
      )}
      {...props}
    >
      {heading && (
        <AutocompletePrimitive.GroupLabel
          data-slot="command-group-heading"
          className="px-3 pt-2 pb-1.5 text-xs font-medium text-muted-foreground"
        >
          {heading}
        </AutocompletePrimitive.GroupLabel>
      )}
      {children}
    </AutocompletePrimitive.Group>
  )
}

function CommandSeparator({ className, ...props }: AutocompletePrimitive.Separator.Props) {
  return (
    <AutocompletePrimitive.Separator
      data-slot="command-separator"
      className={cn('-mx-2 my-1 h-px bg-border-subtle', className)}
      {...props}
    />
  )
}

/**
 * One row. `onSelect` runs on click and on Enter while the row is highlighted,
 * and receives the row's `value`.
 */
function CommandItem({
  className,
  children,
  value,
  keywords,
  onSelect,
  ...props
}: Omit<AutocompletePrimitive.Item.Props, 'onClick' | 'onSelect' | 'value'> & {
  value?: string
  keywords?: string[]
  onSelect?: (value: string) => void
}) {
  const { query, shouldFilter } = React.useContext(CommandContext)
  const text = value ?? (typeof children === 'string' ? children : '')
  const needle = query.trim().toLowerCase()
  if (
    shouldFilter &&
    needle &&
    ![text, ...(keywords ?? [])].some((term) => term.toLowerCase().includes(needle))
  ) {
    return null
  }

  return (
    <AutocompletePrimitive.Item
      data-slot="command-item"
      value={value}
      onClick={() => onSelect?.(text)}
      className={cn(
        "group/command-item relative flex cursor-pointer items-center gap-3 rounded-md px-3 py-2.5 text-sm outline-hidden select-none data-disabled:pointer-events-none data-disabled:opacity-50 data-highlighted:bg-accent-strong data-highlighted:text-accent-foreground [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 [&_svg:not([class*='text-'])]:text-muted-foreground data-highlighted:*:[svg]:text-foreground",
        className,
      )}
      {...props}
    >
      {children}
      <CheckIcon className="ml-auto opacity-0 group-has-data-[slot=command-shortcut]/command-item:hidden group-data-[checked=true]/command-item:opacity-100" />
    </AutocompletePrimitive.Item>
  )
}

function CommandShortcut({ className, ...props }: React.ComponentProps<'span'>) {
  return (
    <span
      data-slot="command-shortcut"
      className={cn(
        'ml-auto text-xs tracking-widest text-muted-foreground group-data-highlighted/command-item:text-foreground',
        className,
      )}
      {...props}
    />
  )
}

/** A single key cap — used for the palette's footer hints and inline shortcuts. */
function CommandKey({ className, ...props }: React.ComponentProps<'kbd'>) {
  return (
    <kbd
      data-slot="command-key"
      className={cn(
        'inline-flex h-5 min-w-6 items-center justify-center rounded-sm bg-card border border-border px-1 font-sans text-xs text-muted-foreground',
        className,
      )}
      {...props}
    />
  )
}

/** One key cap (or a pair) followed by the action it performs. */
function CommandHint({
  keys,
  label,
  className,
  ...props
}: Omit<React.ComponentProps<'div'>, 'children'> & {
  keys: React.ReactNode[]
  label: React.ReactNode
}) {
  return (
    <div data-slot="command-hint" className={cn('flex items-center gap-1.5', className)} {...props}>
      <span className="flex items-center gap-1">
        {keys.map((key, index) => (
          // Hints are static, ordered, and never reordered — index is a stable key.
          // biome-ignore lint/suspicious/noArrayIndexKey: static list
          <CommandKey key={index}>{key}</CommandKey>
        ))}
      </span>
      <span className="text-xs text-muted-foreground">{label}</span>
    </div>
  )
}

/**
 * Bottom bar of the palette. Renders the default navigate/select/close hints
 * when given no children, so callers only pass children to replace them.
 */
function CommandFooter({ className, children, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="command-footer"
      className={cn(
        // Hidden on touch: the footer documents arrow/enter/esc shortcuts,
        // which a phone has no keys for, and it costs 45px of a short viewport.
        'hidden shrink-0 items-center justify-between gap-4 border-t border-border-subtle bg-muted px-4 py-2.5 text-muted-foreground md:flex capitalize',
        className,
      )}
      {...props}
    >
      {children ?? (
        <>
          <div className="flex items-center gap-4">
            <CommandHint
              keys={[
                <MoveUpIcon key="up" className="size-3.5" />,
                <MoveDownIcon key="down" className="size-3.5" />,
              ]}
              label={i18n.t('admin.components.command_palette.hints.navigate')}
            />
            <CommandHint
              keys={[<CornerDownLeftIcon key="enter" className="size-3.5" />]}
              label={i18n.t('admin.components.command_palette.hints.select')}
            />
          </div>
          <CommandHint
            keys={[i18n.t('admin.components.command_palette.hints.esc_key')]}
            label={i18n.t('admin.components.command_palette.hints.close')}
          />
        </>
      )}
    </div>
  )
}

export {
  Command,
  CommandDialog,
  CommandEmpty,
  CommandFooter,
  CommandGroup,
  CommandHint,
  CommandInput,
  CommandItem,
  CommandKey,
  CommandList,
  CommandSeparator,
  CommandShortcut,
}
