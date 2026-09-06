import type { DashboardOperations, ReportingDimensionValue, ReportingQuery } from '@spree/admin-sdk'
import { SpreeError } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  resolveDatePreset,
  Subject,
  usePermissions,
  useResourceKey,
  useStore,
} from '@spree/dashboard-core'
import {
  Card,
  CardContent,
  CardDescription,
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
  CreditCardIcon,
  PackageXIcon,
  RotateCcwIcon,
  TriangleAlertIcon,
  TruckIcon,
} from '@spree/dashboard-ui/icons'
import { useQuery } from '@tanstack/react-query'
import { createFileRoute, Link } from '@tanstack/react-router'
import { format, parseISO } from 'date-fns'
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
import {
  entityDimension,
  metaString,
  useReportingQuery,
  useReportingSchema,
} from '../../../hooks/use-reporting'

export const Route = createFileRoute('/_authenticated/$storeId/')({
  component: DashboardPage,
})

// The five headline metrics, in tile order; labels come from the reporting schema.
const CHART_METRICS = ['gross_revenue', 'orders_count', 'aov', 'units_sold', 'customers_count']

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
  const { data: overview, error: overviewError } = useReportingQuery(overviewQuery)
  const { data: schema } = useReportingSchema()
  const chartMetrics = schema
    ? resolveMetrics(CHART_METRICS, schema)
    : CHART_METRICS.map((name) => ({ name, label: name, format: 'decimal', derived: false }))

  // No `placeholderData`: it belongs to the channel that was selected before,
  // and showing another channel's counts under this one's name is worse than
  // showing the skeleton for a moment.
  const { data: operations, error: operationsError } = useQuery({
    queryKey: useResourceKey('dashboard', 'operations', channelId),
    queryFn: () => adminClient.dashboard.operations({ channel_id: channelParam }),
    staleTime: 5 * 60 * 1000,
  })

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

const OPERATIONS_ROW_CLASS = 'flex items-center gap-3 border-b px-4 py-3 last:border-0'

type OperationsFilter = { id: string; field: string; operator: string; value: string }

const OPERATIONS_ROWS: Array<{
  key: keyof Omit<DashboardOperations, 'low_stock_threshold' | 'channel_id'>
  icon: typeof TruckIcon
  link?: { to: '/$storeId/orders' | '/$storeId/products'; filters: OperationsFilter[] }
}> = [
  {
    key: 'orders_to_fulfill',
    icon: TruckIcon,
    link: {
      to: '/$storeId/orders',
      filters: [
        // Mirrors the `ready_to_ship` scope backing the count.
        { id: 'home-fulfill', field: 'fulfillment_status', operator: 'eq', value: 'unfulfilled' },
      ],
    },
  },
  {
    key: 'payments_to_collect',
    icon: CreditCardIcon,
    link: {
      to: '/$storeId/orders',
      filters: [
        // Mirrors the payments_to_collect statuses backing the count.
        {
          id: 'home-collect',
          field: 'payment_status',
          operator: 'in',
          value: 'none,authorized,partially_paid',
        },
      ],
    },
  },
  { key: 'open_returns', icon: RotateCcwIcon },
  { key: 'low_stock_items', icon: TriangleAlertIcon },
  {
    key: 'out_of_stock_items',
    icon: PackageXIcon,
    link: {
      to: '/$storeId/products',
      filters: [{ id: 'home-oos', field: 'in_stock', operator: 'eq', value: 'false' }],
    },
  },
]

function OperationsCard({
  data,
  className,
  channelId,
  failed,
}: {
  data: DashboardOperations | undefined
  className: string
  /** The screen's channel, or undefined for all channels. */
  channelId: string | undefined
  /** The counts could not be loaded — show a dash rather than a skeleton forever. */
  failed: boolean
}) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()

  return (
    <Card className={className}>
      <CardHeader>
        <CardTitle>{t('admin.pages.home.operations.title')}</CardTitle>
        <CardDescription>{t('admin.pages.home.operations.subtitle')}</CardDescription>
      </CardHeader>
      <CardContent className="p-0">
        <div className="flex flex-col">
          {OPERATIONS_ROWS.map(({ key, icon: Icon, link }) => {
            const count = data?.[key]
            // Order counts are channel-scoped, so their lists must be too;
            // stock counts are store-wide and take no channel filter.
            const filters =
              link && channelId && link.to === '/$storeId/orders'
                ? [
                    ...link.filters,
                    { id: 'home-channel', field: 'channel_id', operator: 'eq', value: channelId },
                  ]
                : link?.filters
            const content = (
              <>
                <span className="flex size-8 shrink-0 items-center justify-center rounded-md border bg-muted/50">
                  <Icon className="size-4 text-muted-foreground" />
                </span>
                <span className="flex-1 text-sm">{t(`admin.pages.home.operations.${key}`)}</span>
                {count === undefined ? (
                  failed ? (
                    <span className="text-sm text-muted-foreground">—</span>
                  ) : (
                    <Skeleton className="h-4 w-8" />
                  )
                ) : (
                  <span
                    className={cn(
                      'text-sm font-semibold tabular-nums',
                      count === 0 && 'text-muted-foreground',
                    )}
                  >
                    {count.toLocaleString()}
                  </span>
                )}
                {link && <ChevronRightIcon className="size-4 text-muted-foreground" />}
              </>
            )

            if (link) {
              return (
                <Link
                  key={key}
                  to={link.to}
                  params={{ storeId }}
                  search={{ filters }}
                  className={cn(OPERATIONS_ROW_CLASS, 'hover:bg-muted/25')}
                >
                  {content}
                </Link>
              )
            }

            return (
              <div key={key} className={OPERATIONS_ROW_CLASS}>
                {content}
              </div>
            )
          })}
        </div>
      </CardContent>
    </Card>
  )
}

type RankingTab = 'customers' | 'categories'

// Each tab is one contract query; the revenue metric doubles as the share bar.
const RANKING_QUERIES: Record<
  RankingTab,
  {
    query: Omit<ReportingQuery, 'time_range' | 'filters'>
    revenueMetric: string
    countMetric: string
  }
> = {
  customers: {
    query: {
      metrics: ['gross_revenue', 'orders_count'],
      dimensions: ['customer'],
      sort: '-gross_revenue',
      limit: 5,
    },
    revenueMetric: 'gross_revenue',
    countMetric: 'orders_count',
  },
  categories: {
    query: {
      metrics: ['net_revenue', 'units_sold'],
      dimensions: ['category'],
      sort: '-net_revenue',
      limit: 5,
    },
    revenueMetric: 'net_revenue',
    countMetric: 'units_sold',
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

  const { query, revenueMetric, countMetric } = RANKING_QUERIES[tab]
  const { data, error, isPlaceholderData } = useReportingQuery({ ...query, ...scope })

  // Placeholder data belongs to the previous tab (other dimension, other
  // metrics) — show the skeleton until this tab's own rows arrive.
  const rows = (isPlaceholderData ? undefined : data)?.rows.map((row) => {
    const dimension = entityDimension(row, tab === 'customers' ? 'customer' : 'category')
    const amount = row.metrics[revenueMetric]
    const count = row.metrics[countMetric]?.value ?? 0
    return {
      key: dimension.id ?? dimension.label,
      dimension,
      amount: amount?.value ?? 0,
      display: amount?.display ?? String(amount?.value ?? 0),
      meta:
        tab === 'customers'
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
      <CardContent className="p-0">
        {rows === undefined ? (
          error ? (
            <p className="px-4 pb-6 pt-2 text-sm text-muted-foreground">
              {t('admin.errors.generic')}
            </p>
          ) : (
            <RankingRowsSkeleton />
          )
        ) : rows.length === 0 ? (
          <p className="px-4 pb-6 pt-2 text-sm text-muted-foreground">
            {t('admin.pages.home.rankings.empty')}
          </p>
        ) : (
          <div className="flex flex-col">
            {rows.map((row, index) => (
              <div key={`${tab}-${row.key ?? index}`} className="border-b px-4 py-3 last:border-0">
                <div className="flex items-baseline justify-between gap-3">
                  <span className="flex min-w-0 items-baseline gap-2 text-sm">
                    <span className="w-5 shrink-0 text-muted-foreground tabular-nums">
                      {index + 1}.
                    </span>
                    <RankingName tab={tab} storeId={storeId} dimension={row.dimension} />
                  </span>
                  <span className="shrink-0 text-right">
                    <span className="block text-sm font-medium tabular-nums">{row.display}</span>
                    <span className="block text-xs text-muted-foreground">{row.meta}</span>
                  </span>
                </div>
                <Progress className="mt-2" value={sharePercent(row.amount, maxAmount)} />
              </div>
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  )
}

function RankingName({
  tab,
  storeId,
  dimension,
}: {
  tab: RankingTab
  storeId: string
  dimension: ReportingDimensionValue
}) {
  const label = <DimensionLabel dimension={dimension} />

  if (!dimension.id) {
    return label
  }

  if (tab === 'customers') {
    return (
      <Link
        to="/$storeId/customers/$customerId"
        params={{ storeId, customerId: dimension.id }}
        className="min-w-0 hover:underline"
      >
        {label}
      </Link>
    )
  }

  return (
    <Link
      to="/$storeId/products/categories/$categoryId"
      params={{ storeId, categoryId: dimension.id }}
      className="min-w-0 hover:underline"
    >
      {label}
    </Link>
  )
}

function RankingRowsSkeleton() {
  return (
    <div className="flex flex-col">
      {['rank-1', 'rank-2', 'rank-3', 'rank-4', 'rank-5'].map((key) => (
        <div key={key} className="border-b px-4 py-3 last:border-0">
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

  const { data } = useReportingQuery({
    metrics: ['net_revenue', 'units_sold'],
    dimensions: ['product'],
    compare: 'previous_period',
    sort: '-net_revenue',
    limit: 5,
    ...scope,
  })

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
              const revenue = row.metrics.net_revenue
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
                <div key={key} className="flex items-center gap-3 border-b px-4 py-3 last:border-0">
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
