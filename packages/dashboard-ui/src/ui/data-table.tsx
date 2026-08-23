import {
  Children,
  cloneElement,
  isValidElement,
  type ReactElement,
  type ReactNode,
  useEffect,
  useLayoutEffect,
  useRef,
} from 'react'
import { cn } from '../lib/utils'

interface TableProps extends React.ComponentProps<'table'> {
  /**
   * Pins the header below the app bar while the page scrolls, and lets the
   * table scroll horizontally so many columns keep readable widths instead of
   * squeezing until cells wrap. Opt-in: it assumes the table is the page's
   * main content — inside cards, sheets or dialogs, keep the default.
   */
  stickyHeader?: boolean
  /**
   * Rounds the last row's outer corners. Opt-in, because it only reads
   * correctly when the table is the last thing inside a rounded container —
   * anything below it (a pagination footer, a card action row) leaves the
   * curve floating mid-surface.
   */
  roundedBottom?: boolean
}

/**
 * The sticky variant renders two tables. CSS can't deliver this with one:
 * `overflow-x` on a wrapper computes `overflow-y` to `auto` as well, so a
 * sticky header inside the horizontal scroller can only pin to that box —
 * which would mean capping its height and scrolling the body inside the card.
 *
 * So the header is rendered twice from the same React element:
 *
 * - A pinned table above the scroller carries the *interactive* header. It is
 *   live React — sort controls, the select-all checkbox and the bulk actions
 *   bar all work — pinned via a zero-height sticky wrapper so it overlays the
 *   space the body's header row reserves rather than stacking above it.
 * - The body table keeps an `invisible` copy as a sizer: it reserves that row,
 *   drives natural column widths, and being `visibility: hidden` is out of the
 *   click path, the tab order and the accessibility tree.
 *
 * A layout-effect measurement copies the sizer's column widths onto the pinned
 * header's cells (same content → same natural widths, so this only nails down
 * rounding), and a scroll listener mirrors the body's `scrollLeft` onto the
 * pinned table so the header tracks horizontal scrolling.
 */
function Table({
  className,
  children,
  stickyHeader = false,
  roundedBottom = false,
  ...props
}: TableProps) {
  const scrollRef = useRef<HTMLDivElement | null>(null)
  const bodyTableRef = useRef<HTMLTableElement | null>(null)
  const pinnedTableRef = useRef<HTMLTableElement | null>(null)

  // Applied on the table so it reaches the last row's edge cells without
  // every TableCell paying for the selector.
  const roundedClasses = roundedBottom
    ? '[&_tbody_tr:last-child_td:first-child]:rounded-bl-xl [&_tbody_tr:last-child_td:last-child]:rounded-br-xl'
    : undefined

  const kids = Children.toArray(children)
  const headerElement = kids.find(
    (kid): kid is ReactElement<React.ComponentProps<'thead'>> =>
      isValidElement(kid) && kid.type === TableHeader,
  )
  const pinned = stickyHeader && headerElement != null

  // Copy the sizer's column widths onto the pinned header on every commit —
  // column toggles, data loads and label changes all land here. Written to the
  // DOM directly rather than through state: a state round-trip re-renders,
  // re-measures, and on tables whose widths don't settle to the exact same
  // fraction each pass (the drag-reorder variant), that loop never terminates.
  // DOM writes can't re-enter React, so oscillation is impossible by
  // construction.
  useLayoutEffect(() => {
    if (pinned) syncColumnWidths(bodyTableRef.current, pinnedTableRef.current)
  })

  // Viewport-driven resizes don't pass through React, so track them directly.
  useEffect(() => {
    if (!pinned) return
    const table = bodyTableRef.current
    if (!table) return
    const observer = new ResizeObserver(() => syncColumnWidths(table, pinnedTableRef.current))
    observer.observe(table)
    return () => observer.disconnect()
  }, [pinned])

  // Mirror the body's horizontal scroll onto the pinned header. Imperative —
  // going through state would re-render the whole table every scroll frame.
  useEffect(() => {
    if (!pinned) return
    const scroller = scrollRef.current
    if (!scroller) return
    const sync = () => {
      const pinnedTable = pinnedTableRef.current
      if (pinnedTable) pinnedTable.style.transform = `translate3d(${-scroller.scrollLeft}px,0,0)`
    }
    sync()
    scroller.addEventListener('scroll', sync, { passive: true })
    return () => scroller.removeEventListener('scroll', sync)
  }, [pinned])

  if (!pinned) {
    return (
      // `overflow-x: auto` computes `overflow-y` to `auto` as well, which makes
      // this a scroll container and traps a sticky <thead> inside it — the
      // header would scroll away with the page. `clip` leaves `overflow-y:
      // visible`, so sticky resolves against the page instead. Narrow viewports
      // keep `auto`, where scrolling a wide table sideways matters more than a
      // sticky header.
      <div className="overflow-x-auto md:overflow-x-clip">
        <table
          className={cn('w-full align-top text-foreground', roundedClasses, className)}
          {...props}
        >
          {children}
        </table>
      </div>
    )
  }

  // `w-max` + `min-w-full`: size to the content, but never narrower than the
  // card, so a table with few columns still fills the width.
  const tableClasses = cn('w-max min-w-full align-top text-foreground', roundedClasses, className)

  return (
    <div className="relative min-w-0">
      {/* Zero-height sticky wrapper: the pinned header overlays the sizer row
          below instead of occupying its own band. The inner div clips the
          horizontal overhang the translateX mirror produces. */}
      <div className="sticky top-header-height z-20 h-0">
        <div className="overflow-hidden">
          {/* `presentation`: this table exists to paint a header that stays put
              and to host its controls. Announcing it as a second table — one
              with column headers but no rows — would just duplicate the header
              names the real table below already provides. The controls inside
              keep their own roles and stay reachable. */}
          <table ref={pinnedTableRef} className={tableClasses} role="presentation">
            {headerElement}
          </table>
        </div>
      </div>
      {/* `min-w-0`: without it this scroller keeps its default
          `min-width: auto`, refuses to shrink below the table's intrinsic
          width, and the overflow escapes to the document instead of scrolling
          here — the whole page then lays out wider than the viewport. */}
      <div ref={scrollRef} className="themed-scrollbar min-w-0 overflow-x-auto">
        <table ref={bodyTableRef} className={tableClasses} {...props}>
          {cloneElement(headerElement, {
            // The sizer: reserves the header row and drives column widths. It
            // stays in the accessibility tree, because this is the table that
            // holds the data rows — hiding it outright would leave every cell
            // with no column header to resolve against. So hide what it draws
            // rather than the row itself, one concern per utility:
            //   `[&_th]:text-transparent` — the labels, which are bare text on
            //     the cells, so this has to out-specify the colour `TableHead`
            //     sets there.
            //   `[&_th>*]:invisible` — any control in a cell, which also drops
            //     it from hit-testing and the tab order.
            //   `[&>tr]:!static` — the sticky positioning the header row
            //     carries for the plain table, which here would lift this row
            //     out of flow and let the first data row slide up under the
            //     pinned copy.
            className: cn(
              headerElement.props.className,
              'select-none [&>tr]:!static [&_th]:text-transparent [&_th>*]:invisible',
            ),
          })}
          {kids.filter((kid) => kid !== headerElement)}
        </table>
      </div>
    </div>
  )
}

function syncColumnWidths(
  bodyTable: HTMLTableElement | null,
  pinnedTable: HTMLTableElement | null,
) {
  if (!bodyTable || !pinnedTable) return
  const inFlowCells = (table: HTMLTableElement) =>
    Array.from(table.querySelectorAll<HTMLElement>('thead tr:first-child > th')).filter(
      // Out-of-flow cells (overlays) don't form columns.
      (cell) => getComputedStyle(cell).position !== 'absolute',
    )
  const sizerCells = inFlowCells(bodyTable)
  const pinnedCells = inFlowCells(pinnedTable)
  for (let i = 0; i < Math.min(sizerCells.length, pinnedCells.length); i++) {
    pinnedCells[i].style.width = `${sizerCells[i].getBoundingClientRect().width}px`
  }
}

function TableHeader({ className, ...props }: React.ComponentProps<'thead'>) {
  return <thead className={cn('align-bottom', className)} {...props} />
}

function TableBody({ className, ...props }: React.ComponentProps<'tbody'>) {
  return <tbody className={cn('align-middle', className)} {...props} />
}

function TableRow({ className, ...props }: React.ComponentProps<'tr'>) {
  return (
    <tr className={cn('group/row hover:bg-accent/25 last:*:border-b-0', className)} {...props} />
  )
}

/**
 * The bottom rule is an inset shadow rather than `border-b` so it stays flush
 * with the bulk action bar, which overlays this row and draws the same shadow.
 * Don't add a border alongside it — a border sits outside the padding box and
 * the shadow inside, so the two stack into a 2px line.
 */
function TableHead({ className, ...props }: React.ComponentProps<'th'>) {
  return (
    <th
      className={cn(
        'text-left text-sm font-medium text-muted-foreground bg-muted p-2 whitespace-nowrap first:pl-4 last:pr-4',
        'shadow-[inset_0_-1px_0_0_var(--border-subtle)]',
        className,
      )}
      {...props}
    />
  )
}

/**
 * Header row. `relative` because the bulk action bar positions against it: a
 * cell can't serve as that anchor, since absolute children of a table cell are
 * clipped to the cell's own width.
 *
 * The `md:sticky` matters only for the plain (non-`stickyHeader`) table, whose
 * wrapper clips instead of scrolling, so the row pins to the page. Inside the
 * sticky variant neither copy has a vertically scrolling ancestor, so it
 * behaves as `relative` there.
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
        'py-3 px-2 border-b border-border-subtle align-middle first:pl-4 last:pr-4',
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
        {/* `sticky left-0` with the viewport's own width: the cell spans the
            full scroll width of a wide table, so centring inside it puts the
            message off-screen on a narrow viewport. This keeps it centred on
            what the merchant can actually see, wherever the table is scrolled. */}
        <div className="sticky left-0 mx-auto w-screen max-w-full">{children}</div>
      </td>
    </tr>
  )
}

export { Table, TableBody, TableCell, TableEmpty, TableHead, TableHeader, TableHeaderRow, TableRow }
