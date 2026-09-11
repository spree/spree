import type { DashboardCounter, DashboardCounters, ReportingQuery } from '@spree/admin-sdk'
import { SpreeError } from '@spree/admin-sdk'
import { Can, resolveDatePreset, Subject, usePermissions, useStore } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
  cn,
  type DateRange,
  DateRangePicker,
  Empty,
  EmptyDescription,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
  Progress,
  ScrollArea,
  Skeleton,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableHeaderRow,
  TableRow,
  Tabs,
  TabsList,
  TabsTrigger,
  Thumbnail,
} from '@spree/dashboard-ui'
import {
  ChartColumnIcon,
  ChevronRightIcon,
  CircleDotIcon,
  CreditCardIcon,
  PackageXIcon,
  RotateCcwIcon,
  TriangleAlertIcon,
  TruckIcon,
} from '@spree/dashboard-ui/icons'
import { createFileRoute, Link, type LinkProps } from '@tanstack/react-router'
import { format, parseISO } from 'date-fns'
import type { CSSProperties } from 'react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { ALL_CHANNELS, ChannelSelect } from '../../../components/spree/channel-select'
import { GrowthBadge } from '../../../components/spree/reporting/growth-badge'
import {
  DimensionLabel,
  ReportSkeleton,
  resolveMetrics,
  sharePercent,
  TimeSeriesChart,
} from '../../../components/spree/reporting/report-view'
import { useDashboardCounters } from '../../../hooks/use-dashboard-counters'
import {
  entityDimension,
  metaString,
  useReportingQuery,
  useReportingSchema,
} from '../../../hooks/use-reporting'
import { useSavedReportByName } from '../../../hooks/use-saved-reports'

export const Route = createFileRoute('/_authenticated/$storeId/')({
  component: DashboardPage,
})

// The five headline metrics, in tile order; labels come from the reporting schema.
const CHART_METRICS = ['total_sales', 'orders', 'average_order_value', 'units_sold', 'customers']

function DashboardPage() {
  const { t } = useTranslation()
  const { permissions } = usePermissions()
  const { timezone } = useStore()
  // Seeded on the store's calendar, not the browser's, and sent as bare dates
  // so the server widens both edges to the store's whole day.
  const [dateRange, setDateRange] = useState<DateRange>(() => {
    const preset = resolveDatePreset('last_30_days', timezone)
    return { from: parseISO(preset.from as string), to: parseISO(preset.to as string) }
  })
  const [channelId, setChannelId] = useState<string>(ALL_CHANNELS)

  // Mirror the server's member-level authorization (Query#required_subjects):
  // widgets whose dimensions the role cannot read are hidden instead of
  // rendering 403-fed skeletons. UX only — the API enforces regardless.
  const rankingTabs: RankingTab[] = [
    ...(permissions.can('read', Subject.Customer) ? (['customers'] as const) : []),
    ...(permissions.can('read', Subject.Category) ? (['categories'] as const) : []),
    ...(permissions.can('read', Subject.Company) ? (['companies'] as const) : []),
    ...(permissions.can('read', Subject.Seller) ? (['sellers'] as const) : []),
  ]

  const channelParam = channelId === ALL_CHANNELS ? undefined : channelId
  // Shared by every widget query — the switcher and date range scope the whole screen.
  const scope: Pick<ReportingQuery, 'time_range' | 'filters'> = {
    time_range: {
      since: format(dateRange.from, 'yyyy-MM-dd'),
      until: format(dateRange.to, 'yyyy-MM-dd'),
    },
    ...(channelParam
      ? { filters: [{ dimension: 'channel', op: 'eq' as const, value: channelParam }] }
      : {}),
  }

  const overviewQuery: ReportingQuery = {
    metrics: CHART_METRICS,
    dimensions: [{ name: 'completed_at', grain: 'day' }],
    compare: 'previous_period',
    ...scope,
  }
  // Placeholder data is the previous channel's or period's result; showing it
  // under the new scope's heading would misattribute the figures.
  const {
    data: overviewData,
    error: overviewError,
    isPlaceholderData: overviewIsStale,
  } = useReportingQuery(overviewQuery)
  const overview = overviewIsStale ? undefined : overviewData
  const { data: schema } = useReportingSchema()
  const chartMetrics = schema
    ? resolveMetrics(CHART_METRICS, schema)
    : CHART_METRICS.map((name) => ({ name, label: name, format: 'decimal', derived: false }))

  const { data: operations, error: operationsError } = useDashboardCounters(channelParam)

  // A role without `read_reports` (or order data) gets a 403 here — say so
  // rather than leaving the skeleton up forever. Any other failure is a plain
  // error, not a permission problem.
  if (overviewError) {
    const forbidden = overviewError instanceof SpreeError && overviewError.status === 403
    return (
      <div className="flex flex-col gap-6">
        <div>
          <h1 className="text-2xl font-bold">{t('admin.pages.home.title')}</h1>
          <p className="text-muted-foreground">{t('admin.pages.home.subtitle')}</p>
        </div>
        <Card>
          <CardContent>
            <Empty>
              <EmptyHeader>
                <EmptyMedia variant="icon">
                  <ChartColumnIcon />
                </EmptyMedia>
                <EmptyTitle>
                  {forbidden ? t('admin.pages.home.unavailable.title') : t('admin.errors.generic')}
                </EmptyTitle>
                <EmptyDescription>
                  {forbidden
                    ? t('admin.pages.home.unavailable.description')
                    : overviewError.message}
                </EmptyDescription>
              </EmptyHeader>
            </Empty>
          </CardContent>
        </Card>
      </div>
    )
  }

  if (!overview) {
    return <DashboardSkeleton />
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">{t('admin.pages.home.title')}</h1>
          <p className="text-muted-foreground">{t('admin.pages.home.subtitle')}</p>
        </div>
        <div className="flex items-center gap-2">
          {/* Scopes order-derived metrics to one channel; stock counts stay store-wide. */}
          <ChannelSelect
            allOption
            triggerClassName="min-w-40"
            value={channelId}
            onChange={setChannelId}
          />
          <DateRangePicker value={dateRange} onChange={setDateRange} />
        </div>
      </div>
      <TimeSeriesChart
        metrics={chartMetrics}
        result={overview}
        dimension="completed_at"
        grain="day"
        compare
      />
      <div className="grid gap-6 lg:grid-cols-5">
        <OperationsCard
          data={operations}
          failed={!!operationsError}
          channelId={channelParam}
          className={rankingTabs.length > 0 ? 'lg:col-span-2' : 'lg:col-span-5'}
        />
        {rankingTabs.length > 0 && <RankingsCard scope={scope} tabs={rankingTabs} />}
      </div>
      <Can I="read" a={Subject.Product}>
        <TopProducts scope={scope} />
      </Can>
    </div>
  )
}

const OPERATIONS_ROW_CLASS =
  'flex items-center gap-3 border-b border-border-subtle px-4 py-3 last:border-0'

/** `orders_to_fulfill` reads as "Orders to fulfill" when nobody has translated
 *  it — better than a raw key for an extension's own counter. */
function humanizeKey(key: string) {
  const words = key.replace(/_/g, ' ')
  return words.charAt(0).toUpperCase() + words.slice(1)
}

/** Icons for the counters core ships. A counter an extension registers
 *  arrives with a label and a link but no icon, so it takes the fallback. */
const COUNTER_ICONS: Record<string, typeof TruckIcon> = {
  orders_to_fulfill: TruckIcon,
  payments_to_collect: CreditCardIcon,
  open_returns: RotateCcwIcon,
  low_stock_items: TriangleAlertIcon,
  out_of_stock_items: PackageXIcon,
}

/** Lists a server-declared link can land on. A resource this dashboard has
 *  no list for renders as a plain row rather than a dead link. */
const COUNTER_ROUTES = {
  orders: '/$storeId/orders',
  returns: '/$storeId/returns',
  exchanges: '/$storeId/exchanges',
  claims: '/$storeId/claims',
  products: '/$storeId/products',
  inventory: '/$storeId/inventory',
} as const

/** The counters core registers, so the skeleton holds the card's height
 *  until the numbers arrive. */
const COUNTER_SKELETON_ROWS = Object.keys(COUNTER_ICONS)

type CounterLink = {
  to: (typeof COUNTER_ROUTES)[keyof typeof COUNTER_ROUTES]
  filters: Array<{ id: string; field: string; operator: string; value: string }>
}

/** The list a counter opens. The server declares the filter beside the count
 *  so the two cannot drift; the client only adds the channel it is viewing. */
function counterLink(
  link: DashboardCounter['link'],
  channelId: string | undefined,
): CounterLink | undefined {
  if (!link) return undefined
  const to = COUNTER_ROUTES[link.resource as keyof typeof COUNTER_ROUTES]
  if (!to) return undefined

  const filters = link.filters.map((filter) => ({ id: `home-${filter.field}`, ...filter }))
  // Order counts are channel-scoped, so their lists must be too; stock and
  // returns are store-wide and take no channel filter.
  if (channelId && link.resource === 'orders') {
    // The orders table's column key, not its ransack attribute — the filter
    // chip looks the column up by key to render "Channel is Web" rather than
    // the raw id.
    filters.push({ id: 'home-channel', field: 'channel', operator: 'eq', value: channelId })
  }
  return { to, filters }
}

function OperationsCard({
  data,
  className,
  channelId,
  failed,
}: {
  data: DashboardCounters | undefined
  className: string
  /** The screen's channel, or undefined for all channels. */
  channelId: string | undefined
  /** The counts could not be loaded — say so rather than show a skeleton forever. */
  failed: boolean
}) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const counters = data?.counters

  return (
    <Card className={className}>
      <CardHeader>
        <CardTitle>{t('admin.pages.home.operations.title')}</CardTitle>
        <CardDescription>{t('admin.pages.home.operations.subtitle')}</CardDescription>
      </CardHeader>
      <CardContent className="p-0">
        <div className="flex flex-col">
          {counters === undefined ? (
            failed ? (
              <p className="px-4 py-3 text-sm text-muted-foreground">
                {t('admin.pages.home.operations.failed')}
              </p>
            ) : (
              COUNTER_SKELETON_ROWS.map((key) => (
                <div key={key} className={OPERATIONS_ROW_CLASS}>
                  <Skeleton className="size-8 rounded-md" />
                  <Skeleton className="h-4 flex-1" />
                  <Skeleton className="h-4 w-8" />
                </div>
              ))
            )
          ) : counters.length === 0 ? (
            <p className="px-4 py-3 text-sm text-muted-foreground">
              {t('admin.pages.home.operations.empty')}
            </p>
          ) : (
            counters.map((counter) => (
              <CounterRow
                key={counter.key}
                counter={counter}
                link={counterLink(counter.link, channelId)}
                storeId={storeId}
              />
            ))
          )}
        </div>
      </CardContent>
    </Card>
  )
}

function CounterRow({
  counter,
  link,
  storeId,
}: {
  counter: DashboardCounter
  link: CounterLink | undefined
  storeId: string
}) {
  const { t } = useTranslation()
  const { store } = useStore()
  const Icon = COUNTER_ICONS[counter.key] ?? CircleDotIcon
  // The server sends a key, never copy, so the interface language always wins.
  // A counter an extension registers without translations reads as its own
  // humanized key rather than a raw slug.
  const label = t(`admin.pages.home.operations.counters.${counter.key}.label`, {
    defaultValue: humanizeKey(counter.key),
  })
  // The low stock sentence names the store's threshold, which the shell
  // already holds — so the count stays a number on the wire and the sentence
  // stays a translation.
  const description = t(`admin.pages.home.operations.counters.${counter.key}.description`, {
    defaultValue: '',
    count: store?.preferred_low_stock_threshold ?? 0,
  })
  const content = (
    <>
      <span className="flex size-8 shrink-0 items-center justify-center rounded-md border">
        <Icon className="size-4 text-muted-foreground" />
      </span>
      <span className="flex min-w-0 flex-1 flex-col">
        <span className="text-sm">{label}</span>
        {description && (
          <span className="truncate text-xs text-muted-foreground">{description}</span>
        )}
      </span>
      <span
        className={cn(
          'text-sm font-semibold tabular-nums',
          counter.value === 0 && 'text-muted-foreground',
        )}
      >
        {counter.value.toLocaleString()}
      </span>
      {link && <ChevronRightIcon className="size-4 text-muted-foreground" />}
    </>
  )

  if (link) {
    return (
      <Link
        to={link.to}
        params={{ storeId }}
        search={{ filters: link.filters }}
        className={cn(OPERATIONS_ROW_CLASS, 'hover:bg-accent/50')}
      >
        {content}
      </Link>
    )
  }

  return <div className={OPERATIONS_ROW_CLASS}>{content}</div>
}

type RankingTab = 'customers' | 'categories' | 'companies' | 'sellers'

// Each tab is one contract query; the revenue metric doubles as the share bar.
/** One row's height. The rows, the five-row container and the loading
 *  skeleton all derive from it, so they cannot drift apart. */
const RANKING_ROW_HEIGHT = '5.25rem'

const RANKING_QUERIES: Record<
  RankingTab,
  {
    /** Single-dimension by construction: the card renders one name per row. */
    query: Omit<ReportingQuery, 'time_range' | 'filters' | 'dimensions'> & {
      dimensions: [string]
    }
    revenueMetric: string
    countMetric: string
    /** Where a row points. The route travels with the query that produced the
     *  row, so a new tab cannot forget one. */
    rowLink: (storeId: string, id: string) => LinkProps
    /** The seeded report this ranking is the top five of; the card links to it
     *  by name, since a report is addressed by id and names are translated. */
    reportKey: string
  }
> = {
  customers: {
    query: {
      metrics: ['total_sales', 'orders'],
      dimensions: ['customer'],
      sort: '-total_sales',
      limit: 5,
    },
    revenueMetric: 'total_sales',
    countMetric: 'orders',
    rowLink: (storeId, customerId) => ({
      to: '/$storeId/customers/$customerId',
      params: { storeId, customerId },
    }),
    reportKey: 'top_customers',
  },
  categories: {
    query: {
      metrics: ['net_sales', 'units_sold'],
      dimensions: ['category'],
      sort: '-net_sales',
      limit: 5,
    },
    revenueMetric: 'net_sales',
    countMetric: 'units_sold',
    rowLink: (storeId, categoryId) => ({
      to: '/$storeId/products/categories/$categoryId',
      params: { storeId, categoryId },
    }),
    reportKey: 'top_categories',
  },
  companies: {
    query: {
      metrics: ['total_sales', 'orders'],
      dimensions: ['company'],
      sort: '-total_sales',
      limit: 5,
    },
    revenueMetric: 'total_sales',
    countMetric: 'orders',
    rowLink: (storeId, companyId) => ({
      to: '/$storeId/companies/$companyId',
      params: { storeId, companyId },
    }),
    reportKey: 'top_companies',
  },
  // What each seller sold, on the line items that were theirs.
  sellers: {
    query: {
      metrics: ['net_sales', 'units_sold'],
      dimensions: ['seller'],
      sort: '-net_sales',
      limit: 5,
    },
    revenueMetric: 'net_sales',
    countMetric: 'units_sold',
    rowLink: (storeId, sellerId) => ({
      to: '/$storeId/sellers/$sellerId',
      params: { storeId, sellerId },
    }),
    reportKey: 'seller_payouts',
  },
}

function RankingsCard({
  scope,
  tabs,
}: {
  scope: Pick<ReportingQuery, 'time_range' | 'filters'>
  /** Permission-filtered, non-empty — the parent hides the card otherwise. */
  tabs: RankingTab[]
}) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const [tab, setTab] = useState<RankingTab>(tabs[0])

  const { query, revenueMetric, countMetric, rowLink, reportKey } = RANKING_QUERIES[tab]
  // The seeded report's own name, from the same keys the seeder writes it with.
  const reportName = t(`admin.pages.home.rankings.report_names.${reportKey}`)
  const { report } = useSavedReportByName(reportName)
  // Read from the query rather than stored beside it: two copies can disagree,
  // and a row asked for a dimension it was not grouped by renders unnamed.
  const [dimensionName] = query.dimensions
  const { data, error, isPlaceholderData } = useReportingQuery({ ...query, ...scope })

  // Placeholder data belongs to the previous tab (other dimension, other
  // metrics) — show the skeleton until this tab's own rows arrive.
  const rows = (isPlaceholderData ? undefined : data)?.rows.map((row) => {
    const dimension = entityDimension(row, dimensionName)
    const amount = row.metrics[revenueMetric]
    const count = row.metrics[countMetric]?.value ?? 0
    return {
      key: dimension.id ?? dimension.label,
      dimension,
      amount: amount?.value ?? 0,
      display: amount?.display ?? String(amount?.value ?? 0),
      // Named after the metric being counted, not the tab: companies count
      // orders and sellers count units, so a tab-based ternary mislabels one
      // of them the moment a tab is added.
      meta:
        countMetric === 'orders'
          ? t('admin.pages.home.rankings.orders_count', { count })
          : t('admin.pages.home.rankings.units_count', { count }),
    }
  })

  const maxAmount = rows?.length ? Math.max(...rows.map((row) => row.amount)) : 0

  return (
    <Card className="lg:col-span-3">
      <CardHeader className="flex flex-row items-start justify-between gap-4">
        <div className="flex flex-col gap-1.5">
          <CardTitle>{t('admin.pages.home.rankings.title')}</CardTitle>
          <CardDescription>{t('admin.pages.home.rankings.subtitle')}</CardDescription>
        </div>
        <Tabs value={tab} onValueChange={(value) => setTab(value as RankingTab)}>
          <TabsList>
            {tabs.map((value) => (
              <TabsTrigger key={value} value={value}>
                {t(`admin.pages.home.rankings.tabs.${value}`)}
              </TabsTrigger>
            ))}
          </TabsList>
        </Tabs>
      </CardHeader>
      {/* Five rows tall whatever the tab holds — rows, a skeleton, an empty
          note or an error all live at this height, so the page below never
          moves as tabs are switched or data arrives. */}
      <CardContent
        className="h-[calc(var(--ranking-row)*5)] p-0"
        style={{ '--ranking-row': RANKING_ROW_HEIGHT } as CSSProperties}
      >
        {rows === undefined ? (
          error ? (
            <p className="px-4 pt-4 text-sm text-muted-foreground">{t('admin.errors.generic')}</p>
          ) : (
            <RankingRowsSkeleton />
          )
        ) : rows.length === 0 ? (
          <p className="px-4 pt-4 text-sm text-muted-foreground">
            {t('admin.pages.home.rankings.empty')}
          </p>
        ) : (
          // Five rows tall, whatever the tab returns: the card keeps one height
          // so the page below it does not jump as tabs are switched, and a
          // longer ranking scrolls rather than stretching the layout.
          <ScrollArea className="h-full">
            <div className="flex flex-col">
              {rows.map((row, index) => {
                const body = (
                  <>
                    <div className="flex items-baseline justify-between gap-3">
                      <span className="flex min-w-0 items-baseline gap-2 text-sm">
                        <span className="w-5 shrink-0 text-muted-foreground tabular-nums">
                          {index + 1}.
                        </span>
                        <DimensionLabel dimension={row.dimension} />
                      </span>
                      <span className="shrink-0 text-right">
                        <span className="block text-sm font-medium tabular-nums">
                          {row.display}
                        </span>
                        <span className="block text-xs text-muted-foreground">{row.meta}</span>
                      </span>
                    </div>
                    <Progress className="mt-2 pl-7" value={sharePercent(row.amount, maxAmount)} />
                  </>
                )
                const rowKey = `${tab}-${row.key ?? index}`
                // A fixed row height: only customer rows carry a sub-line, so
                // without it the list is a different height on every tab and
                // the card resizes as they are switched.
                const rowClass =
                  'flex h-(--ranking-row) flex-col justify-center border-b px-4 text-foreground no-underline last:border-0'

                // The whole row is the target rather than just the name: a
                // ranking row is one thing, and a link the width of a name is a
                // small target beside the figures it belongs to. A row whose key
                // has no record behind it ("Unassigned") stays inert.
                return row.dimension.id ? (
                  <Link
                    key={rowKey}
                    {...rowLink(storeId, row.dimension.id)}
                    className={cn(rowClass, 'transition-colors hover:bg-accent/60')}
                  >
                    {body}
                  </Link>
                ) : (
                  <div key={rowKey} className={rowClass}>
                    {body}
                  </div>
                )
              })}
            </div>
          </ScrollArea>
        )}
      </CardContent>
      {/* Five rows is the top of a longer report; the footer is the way to the
          rest of it, below the rows rather than competing with the tabs. */}
      <Can I="read" a={Subject.SavedReport}>
        <CardFooter className="justify-end">
          <Button asChild variant="ghost" size="sm" disabled={!report}>
            {report ? (
              <Link to="/$storeId/reports/$reportId" params={{ storeId, reportId: report.id }}>
                {t('admin.pages.home.rankings.view_report')}
                <ChevronRightIcon className="size-4" />
              </Link>
            ) : (
              // The report is looked up by name, so until it resolves — or if
              // a merchant deleted that built-in — the list is the honest
              // destination rather than a link to nothing.
              <Link to="/$storeId/reports" params={{ storeId }} search={{ search: reportName }}>
                {t('admin.pages.home.rankings.view_report')}
                <ChevronRightIcon className="size-4" />
              </Link>
            )}
          </Button>
        </CardFooter>
      </Can>
    </Card>
  )
}

function RankingRowsSkeleton() {
  return (
    <div className="flex flex-col">
      {['rank-1', 'rank-2', 'rank-3', 'rank-4', 'rank-5'].map((key) => (
        <div
          key={key}
          className="flex h-(--ranking-row) flex-col justify-center border-b px-4 last:border-0"
        >
          <div className="flex items-center justify-between gap-3">
            <Skeleton className="h-4 w-40" />
            <Skeleton className="h-4 w-16" />
          </div>
          <Skeleton className="mt-2 h-1 w-full rounded-full" />
        </div>
      ))}
    </div>
  )
}

function TopProducts({ scope }: { scope: Pick<ReportingQuery, 'time_range' | 'filters'> }) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()

  const { data: result, isPlaceholderData } = useReportingQuery({
    metrics: ['net_sales', 'units_sold'],
    dimensions: ['product'],
    compare: 'previous_period',
    sort: '-net_sales',
    limit: 5,
    ...scope,
  })
  // Rows from the previous scope would sit under the new channel's heading.
  const data = isPlaceholderData ? undefined : result

  if (!data || data.rows.length === 0) {
    return null
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.pages.home.top_products')}</CardTitle>
        <CardDescription>{t('admin.pages.home.top_products_description')}</CardDescription>
      </CardHeader>
      <CardContent className="p-0">
        <Table roundedBottom>
          <TableHeader>
            <TableHeaderRow>
              <TableHead>{t('admin.pages.home.columns.product')}</TableHead>
              <TableHead className="text-right">{t('admin.pages.home.columns.price')}</TableHead>
              <TableHead className="text-right">{t('admin.pages.home.columns.sold')}</TableHead>
              <TableHead className="text-right">{t('admin.fields.total.label')}</TableHead>
              <TableHead className="text-right">{t('admin.pages.home.columns.trend')}</TableHead>
            </TableHeaderRow>
          </TableHeader>
          <TableBody>
            {data.rows.map((row) => {
              const product = entityDimension(row, 'product')
              const productId = product.id
              const revenue = row.metrics.net_sales
              const thumbnail = metaString(product, 'thumbnail_url') ?? null
              const price = metaString(product, 'price')

              return (
                <TableRow key={productId ?? product.label}>
                  <TableCell>
                    {productId ? (
                      <Link
                        to="/$storeId/products/$productId"
                        params={{ storeId, productId }}
                        className="flex items-center gap-3 hover:underline"
                      >
                        <Thumbnail src={thumbnail} size="sm" />
                        <span className="font-medium">{product.label}</span>
                      </Link>
                    ) : (
                      <span className="flex items-center gap-3">
                        <Thumbnail src={thumbnail} size="sm" />
                        <span className="font-medium">{product.label}</span>
                      </span>
                    )}
                  </TableCell>
                  <TableCell className="text-right text-muted-foreground">{price ?? '-'}</TableCell>
                  <TableCell className="text-right">{row.metrics.units_sold?.value ?? 0}</TableCell>
                  <TableCell className="text-right font-medium">
                    {revenue?.display ?? revenue?.value}
                  </TableCell>
                  <TableCell className="text-right">
                    <GrowthBadge growth={revenue?.growth} />
                  </TableCell>
                </TableRow>
              )
            })}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  )
}

function DashboardSkeleton() {
  const { t } = useTranslation()
  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-2xl font-bold">{t('admin.pages.home.title')}</h1>
        <p className="text-muted-foreground">{t('admin.pages.home.subtitle')}</p>
      </div>
      <ReportSkeleton />
      <div className="grid gap-6 lg:grid-cols-5">
        <Card className="lg:col-span-2">
          <CardHeader>
            <Skeleton className="h-5 w-32" />
            <Skeleton className="h-4 w-56" />
          </CardHeader>
          <CardContent className="p-0">
            <div className="flex flex-col">
              {['op-1', 'op-2', 'op-3', 'op-4', 'op-5'].map((key) => (
                <div
                  key={key}
                  className="flex items-center gap-3 border-b border-border-subtle px-4 py-3 last:border-0"
                >
                  <Skeleton className="size-8 rounded-md" />
                  <Skeleton className="h-4 w-32 flex-1" />
                  <Skeleton className="h-4 w-8" />
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
        <Card className="lg:col-span-3">
          <CardHeader>
            <Skeleton className="h-5 w-32" />
            <Skeleton className="h-4 w-56" />
          </CardHeader>
          <CardContent className="p-0">
            <RankingRowsSkeleton />
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
