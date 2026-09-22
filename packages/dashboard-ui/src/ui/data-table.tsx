import {
  Children,
  cloneElement,
  isValidElement,
  type ReactElement,
  type ReactNode,
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
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
   * Rounds the last row's outer corners.
   *
   * Left unset this resolves itself: the corners round only when the table's
   * wrapper is the last element in its container, which is exactly when the
   * row's edge is the card's edge. Pass `false` to suppress it, or `true` to
   * force it where the container's own markup hides that (a table wrapped in
   * an extra element that is not itself last).
   *
   * The rule matters in both directions, and callers had it wrong both ways: a
   * table with a pagination footer under it drew a curve floating mid-surface,
   * and one that ended the card left a square hover overflowing the card's
   * own radius.
   */
  roundedBottom?: boolean
  /**
   * Rounds the header's outer corners, for a table that starts a card. The
   * header's own square corners otherwise sit on top of the card's radius and
   * clip it — the mirror of the `roundedBottom` case, and unset by default
   * because a table usually has a card header or some content above it.
   *
   * Applied from `sm` up, matching where a full-bleed table gains its frame:
   * below that the table spans the page gutter with square edges, and curved
   * header cells there would round nothing.
   */
  roundedTop?: boolean
  /**
   * Scrolls sideways at every width, not just on narrow viewports. For a table
   * in a bounded container — a card, a sheet, a dialog — where the default
   * `clip` puts the last columns out of reach with no way to get at them: the
   * container is narrow while the viewport is not, so the breakpoint never
   * fires. Not for a page's main table, where `overflow-x: auto` computing
   * `overflow-y` to `auto` would trap a sticky header.
   */
  scrollX?: boolean
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
  roundedBottom,
  roundedTop,
  scrollX = false,
  ...props
}: TableProps) {
  const scrollRef = useRef<HTMLDivElement | null>(null)
  const bodyTableRef = useRef<HTMLTableElement | null>(null)
  const pinnedTableRef = useRef<HTMLTableElement | null>(null)
  const wrapperRef = useRef<HTMLDivElement | null>(null)
  const [headerPinned, setHeaderPinned] = useState(false)
  // Horizontal overflow, and whether the last column is already in view. The
  // first decides whether the sticky scrollbar is worth showing at all; the
  // second fades the right edge only while something is still hidden there.
  const [overflowsX, setOverflowsX] = useState(false)
  const [atRightEdge, setAtRightEdge] = useState(false)
  // The proxy bar's inner width, so its thumb is the same size as the real
  // scroller's would be.
  const [tableWidth, setTableWidth] = useState(0)
  const stickyBarRef = useRef<HTMLDivElement | null>(null)

  // The header row is pinned once the wrapper's top has passed the band the row
  // sticks to. Measured from the element's own rect on scroll rather than with
  // an IntersectionObserver: the wrapper sits inside a clipped, internally
  // scrolled sheet, where a zero-height sentinel never registers.
  useEffect(() => {
    if (!roundedTop) return
    const wrapper = wrapperRef.current
    if (!wrapper) return

    // Whatever chrome sits above the scroll area publishes the band the row
    // pins below — a page header, or nothing at all.
    const stickyOffset = () =>
      Number.parseFloat(
        getComputedStyle(document.documentElement).getPropertyValue('--spacing-header-height'),
      ) || 0

    const update = () => setHeaderPinned(wrapper.getBoundingClientRect().top < stickyOffset())
    update()

    // Capture phase on the document: the scroll happens on some ancestor and
    // scroll events do not bubble, so a listener on the element itself would
    // never fire.
    document.addEventListener('scroll', update, { capture: true, passive: true })
    window.addEventListener('resize', update)
    return () => {
      document.removeEventListener('scroll', update, { capture: true })
      window.removeEventListener('resize', update)
    }
  }, [roundedTop])

  // Applied on the table so it reaches the last row's edge cells without
  // every TableCell paying for the selector.
  // `td:only-child` covers the empty and skeleton rows, whose single spanning
  // cell is both first and last child — matching on those alone rounds one
  // corner and leaves the other square against the card's curve.
  //
  // `in-[&:last-child]` gates the whole set on the table's wrapper being the
  // last element in its container: with a pagination footer under it the
  // wrapper is not last, so the corners stay square on their own. Explicitly
  // passing the prop opts out of that test in either direction.
  // Both variants are written out in full rather than composed at runtime:
  // Tailwind scans this file as text, so a class it never sees spelled out is
  // a class it never generates.
  // `sm:`, matching `roundedTop` and where a full-bleed table gains its frame:
  // below that the table spans the page gutter with square edges, and rounded
  // cells there would round nothing.
  const alwaysRounded =
    'sm:[&_tbody_tr:last-child_td:first-child]:rounded-bl-xl sm:[&_tbody_tr:last-child_td:last-child]:rounded-br-xl sm:[&_tbody_tr:last-child_td:only-child]:rounded-b-xl'
  // Applied to the outermost wrapper, not the table: `in-[:last-child]` is
  // satisfied by *any* last-child ancestor, and the sticky variant nests two
  // more divs that are both last inside it. Gating on the wrapper the
  // pagination is actually a sibling of is the only test that means "nothing
  // follows this table".
  const roundedWhenLast =
    'last:[&_tbody_tr:last-child_td:first-child]:rounded-bl-xl last:[&_tbody_tr:last-child_td:last-child]:rounded-br-xl last:[&_tbody_tr:last-child_td:only-child]:rounded-b-xl'
  // `true`/`false` decide on the table itself; unset defers to the wrapper's
  // own position among its siblings.
  // `thead` cells carry the header's background, so the radius belongs on the
  // cells rather than the row — a rounded row still shows square cell corners.
  // The header row wears the frame's radius only while it is actually sitting
  // in that corner. `data-header-pinned` on the wrapper (driven by the
  // sentinel below) squares it off the moment the row pins, where a curve
  // would read as a notch cut out of the rows.
  // Dropped outright while pinned rather than overridden by a `rounded-none`
  // class: the two utilities have identical specificity, so which one won came
  // down to their order in the stylesheet — and the rounding did.
  const topRounded =
    roundedTop && !headerPinned
      ? 'sm:[&_thead_tr:first-child_th:first-child]:rounded-tl-xl sm:[&_thead_tr:first-child_th:last-child]:rounded-tr-xl sm:[&_thead_tr:first-child_th:only-child]:rounded-t-xl'
      : undefined
  const tableRoundedClasses = cn(roundedBottom === true ? alwaysRounded : undefined, topRounded)
  const wrapperRoundedClasses = roundedBottom === undefined ? roundedWhenLast : undefined

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

  // Track horizontal overflow so the edge fade and the sticky scrollbar only
  // appear when the table actually has columns out of view — a table that fits
  // gets neither, and pays nothing for them.
  useEffect(() => {
    if (!pinned) return
    const scroller = scrollRef.current
    const table = bodyTableRef.current
    if (!scroller || !table) return
    const measure = () => {
      const max = scroller.scrollWidth - scroller.clientWidth
      setOverflowsX(max > 1)
      setAtRightEdge(scroller.scrollLeft >= max - 1)
      setTableWidth(scroller.scrollWidth)
      // Keep the proxy in step when the table is scrolled by any other means —
      // a wheel, a keyboard, focusing a cell off-screen.
      const bar = stickyBarRef.current
      if (bar && bar.scrollLeft !== scroller.scrollLeft) bar.scrollLeft = scroller.scrollLeft
    }
    // Not measured inline: this effect runs in the frame `pinned` flips, when
    // the scroller has only just been mounted and its `scrollWidth` still
    // reads as its `clientWidth`. Measuring then records no overflow, and on a
    // table whose columns never change size afterwards nothing would correct
    // it. A frame later the layout is real.
    const firstMeasure = requestAnimationFrame(measure)
    scroller.addEventListener('scroll', measure, { passive: true })
    // Both boxes: the columns can grow and the scroller can shrink, and either
    // crosses the threshold on its own.
    const observer = new ResizeObserver(measure)
    observer.observe(scroller)
    observer.observe(table)
    return () => {
      cancelAnimationFrame(firstMeasure)
      scroller.removeEventListener('scroll', measure)
      observer.disconnect()
    }
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
      <div
        className={cn(
          '@container/table-scroll overflow-x-auto',
          // The sticky variant's scroller is themed; a scrollbar this one
          // actually shows should match it.
          scrollX ? 'themed-scrollbar' : 'md:overflow-x-clip',
          wrapperRoundedClasses,
        )}
      >
        <table
          className={cn('w-full align-top text-foreground', tableRoundedClasses, className)}
          {...props}
        >
          {children}
        </table>
      </div>
    )
  }

  // `w-max` + `min-w-full`: size to the content, but never narrower than the
  // card, so a table with few columns still fills the width.
  const tableClasses = cn(
    'w-max min-w-full align-top text-foreground',
    tableRoundedClasses,
    className,
  )

  return (
    <div ref={wrapperRef} className={cn('relative min-w-0', wrapperRoundedClasses)}>
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
          <table
            ref={pinnedTableRef}
            data-pinned-header
            className={tableClasses}
            role="presentation"
          >
            {headerElement}
          </table>
        </div>
      </div>
      {/* `min-w-0`: without it this scroller keeps its default
          `min-width: auto`, refuses to shrink below the table's intrinsic
          width, and the overflow escapes to the document instead of scrolling
          here — the whole page then lays out wider than the viewport. */}
      <div
        ref={scrollRef}
        // `@container/table-scroll`: the empty-state row sizes itself to this
        // element's width rather than the viewport's.
        //
        // `overflow-x: auto`, always. It computes `overflow-y` to `auto` as
        // well, which makes this a scroll container that cannot scroll
        // vertically — so Page Up/Down land here and do nothing while the
        // pointer is over the table. `overflow-y: hidden` below takes that back
        // without costing the horizontal scrollbar: reaching the last column is
        // not negotiable, and `clip` loses it or squeezes the columns to fit.
        className="@container/table-scroll themed-scrollbar min-w-0 overflow-x-auto overflow-y-hidden"
      >
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

      {/* Two halves of one answer to "there is more table to the right".
          The fade says SO, without adding chrome: it sits over the right edge,
          is purely decorative, and disappears the moment the last column is
          reached. The bar below is how you GET there — a table's own scrollbar
          sits at its bottom, which on a long list is far below the fold exactly
          when a reader needs to know the table scrolls at all. */}
      {overflowsX && (
        <div
          aria-hidden
          className={cn(
            'pointer-events-none absolute top-0 bottom-0 right-0 w-12 transition-opacity duration-200 ease-out',
            // Ends where the proxy bar begins, so the gradient does not wash
            // over the bar's track and leave it half-visible at the right.
            'mb-3 bg-gradient-to-l from-card to-transparent',
            atRightEdge ? 'opacity-0' : 'opacity-100',
          )}
        />
      )}

      {/* Mirrors the real scroller rather than replacing it: dragging this
          writes `scrollLeft` on the table, and the table's own scroll writes
          back. `sticky bottom-0` keeps it on screen for as long as any part of
          the table is, so it is reachable from the first row rather than only
          from the last. */}
      {overflowsX && (
        <div
          ref={stickyBarRef}
          onScroll={(event) => {
            const scroller = scrollRef.current
            if (scroller) scroller.scrollLeft = event.currentTarget.scrollLeft
          }}
          // `translate-y-px` tucks it against the frame's bottom edge rather
          // than floating a hairline above it.
          className="themed-scrollbar sticky bottom-0 z-10 -mt-3 translate-y-px overflow-x-auto overflow-y-hidden"
        >
          <div style={{ width: tableWidth, height: 1 }} />
        </div>
      )}
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
    <tr
      className={cn('group/row hover:bg-accent-strong/50 last:*:border-b-0', className)}
      {...props}
    />
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
        'text-left text-sm font-normal text-muted-foreground bg-muted px-3 py-2.5 h-9 sm:p-2 whitespace-nowrap first:pl-4 last:pr-4',
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
        // `h-16` on touch is a floor, not a fixed height: a table cell treats
        // `height` as a minimum, so a row with a thumbnail or a wrapped
        // second line still grows past it.
        'h-16 py-3 px-3 sm:h-auto sm:py-3 sm:px-2 border-b border-border-subtle align-middle first:pl-4 last:pr-4',
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
        {/* The cell spans the table's full scroll width, so centring inside it
            puts the message off-screen once the table is wider than its
            container. `sticky left-0` pins this to the scroller's left edge and
            `100cqw` sizes it to the scroller rather than the viewport — sizing
            it to the viewport made the row itself the widest thing in the
            table and produced a scrollbar on a list that had nothing to
            scroll. */}
        <div className="sticky left-0 flex w-[100cqw] justify-center">{children}</div>
      </td>
    </tr>
  )
}

export { Table, TableBody, TableCell, TableEmpty, TableHead, TableHeader, TableHeaderRow, TableRow }
