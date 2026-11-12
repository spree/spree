/**
 * The look of a button that opens a picker: a select, a combobox, a date
 * range. Shaped like a text field, so a picker and an input on one row read
 * as the same kind of control. `data-size="sm"` is the toolbar size.
 *
 * `min-h-8` matches `<Input>`, and stops the trigger collapsing to the
 * chevron's height when its value renders empty.
 */
export const fieldTriggerClassName =
  "flex w-full min-h-8 cursor-pointer items-center justify-between gap-1.5 rounded-xl border border-field-border shadow-control bg-card py-1.5 pr-2 pl-2.5 text-base font-normal leading-normal text-foreground transition-[color,background-color,border-color,box-shadow] duration-100 ease-out outline-none select-none not-disabled:hover:bg-field-hover focus:border-blue-500 focus:shadow-field-focus disabled:cursor-not-allowed disabled:bg-muted disabled:text-muted-foreground aria-invalid:border-destructive data-[size=sm]:h-8 data-[size=sm]:min-h-8 data-[size=sm]:gap-2 data-[size=sm]:px-2 data-[size=sm]:py-1 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4"
