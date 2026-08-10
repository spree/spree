import type { ReactNode } from 'react'
import { cn } from '../lib/utils'

function Table({ className, ...props }: React.ComponentProps<'table'>) {
  return (
    // `overflow-x: auto` computes `overflow-y` to `auto` as well, which makes
    // this a scroll container and traps a sticky <thead> inside it — the header
    // would scroll away with the page. `clip` leaves `overflow-y: visible`, so
    // sticky resolves against the page instead. Narrow viewports keep `auto`,
    // where scrolling a wide table sideways matters more than a sticky header.
    <div className="overflow-x-auto md:overflow-x-clip">
      <table className={cn('w-full align-top text-foreground', className)} {...props} />
    </div>
  )
}

function TableHeader({ className, ...props }: React.ComponentProps<'thead'>) {
  return <thead className={cn('align-bottom', className)} {...props} />
}

function TableBody({ className, ...props }: React.ComponentProps<'tbody'>) {
  return <tbody className={cn('align-middle', className)} {...props} />
}

function TableRow({ className, ...props }: React.ComponentProps<'tr'>) {
  return (
    <tr className={cn('group/row hover:bg-muted/60 last:*:border-b-0', className)} {...props} />
  )
}

/**
 * The background is opaque rather than the `bg-muted/50` this used to carry: the
 * row is sticky, so a translucent header would show the rows scrolling beneath
 * it.
 *
 * The bottom rule is an inset shadow rather than `border-b`: a table border
 * stops painting over the rows sliding underneath a stuck row, so the line
 * disappears exactly when the header is doing its job. The shadow is drawn
 * inside the padding box and keeps rendering while stuck. Using both would
 * stack — a border sits outside the padding box, so they don't share a pixel.
 */
function TableHead({ className, ...props }: React.ComponentProps<'th'>) {
  return (
    <th
      className={cn(
        'text-left text-sm font-medium text-muted-foreground bg-muted p-2 whitespace-nowrap first:pl-4 last:pr-4',
        'shadow-[inset_0_-1px_0_0_var(--color-border)]',
        className,
      )}
      {...props}
    />
  )
}

/**
 * Header row. Sticks below the app header on scroll so column labels stay
 * readable down a long list.
 *
 * Sticky belongs on the row rather than the cells: a `relative` row is also the
 * containing block for anything absolutely positioned across it (the bulk
 * action bar), and a cell can't be both the sticky element and that anchor —
 * absolute children of a cell are clipped to the cell's own width.
 */
function TableHeaderRow({ className, ...props }: React.ComponentProps<'tr'>) {
  return (
    <tr className={cn('relative md:sticky md:top-header-height md:z-20', className)} {...props} />
  )
}

function TableCell({ className, ...props }: React.ComponentProps<'td'>) {
  return (
    <td
      className={cn(
        'py-3 px-2 border-b border-border align-middle first:pl-4 last:pr-4 group-last/row:first:rounded-bl-xl group-last/row:last:rounded-br-xl',
        className,
      )}
      {...props}
    />
  )
}

function TableEmpty({ children, colSpan }: { children: ReactNode; colSpan: number }) {
  return (
    <tr>
      <td colSpan={colSpan} className="py-12 text-center text-muted-foreground">
        {children}
      </td>
    </tr>
  )
}

export { Table, TableBody, TableCell, TableEmpty, TableHead, TableHeader, TableHeaderRow, TableRow }
