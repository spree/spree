import type {
  DashboardOperations,
  ReportingDimensionValue,
  ReportingQuery,
  ReportingResult,
} from '@spree/admin-sdk'
import { adminClient, Can, Subject, usePermissions } from '@spree/dashboard-core'
import {
  Badge,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  type ChartConfig,
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
  type DateRange,
  DateRangePicker,
  Skeleton,
} from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { createFileRoute, Link } from '@tanstack/react-router'
import { subDays } from 'date-fns'
import {
  ChevronRightIcon,
  CreditCardIcon,
  MinusIcon,
  PackageIcon,
  PackageXIcon,
  RotateCcwIcon,
  TrendingDownIcon,
  TrendingUpIcon,
  TriangleAlertIcon,
  TruckIcon,
} from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Bar, CartesianGrid, ComposedChart, Line, XAxis } from 'recharts'
import { ALL_CHANNELS, ChannelSelect } from '../../../components/spree/channel-select'
import {
  entityDimension,
  metaString,
  rawDimension,
  useReportingQuery,
} from '../../../hooks/use-reporting'

export const Route = createFileRoute('/_authenticated/$storeId/')({
  component: DashboardPage,
})

// UI metric keys (stable i18n keys) → registered reporting metric names.
const CHART_METRICS = {
  sales: 'gross_revenue',
  orders: 'orders_count',
  avg_order_value: 'aov',
  units: 'units_sold',
  customers: 'customers_count',
} as const

type ChartMetric = keyof typeof CHART_METRICS

function DashboardPage() {
  const { t } = useTranslation()
  const { permissions } = usePermissions()
  const [dateRange, setDateRange] = useState<DateRange>({
    from: subDays(new Date(), 30),
    to: new Date(),
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
    time_range: { since: dateRange.from.toISOString(), until: dateRange.to.toISOString() },
    ...(channelParam
      ? { filters: [{ dimension: 'channel', op: 'eq' as const, value: channelParam }] }
      : {}),
  }

  const { data: overview } = useReportingQuery({
    metrics: Object.values(CHART_METRICS),
    dimensions: [{ name: 'completed_at', grain: 'day' }],
    compare: 'previous_period',
    ...scope,
  })

  const { data: operations } = useQuery({
    queryKey: ['dashboard', 'operations', channelId],
    queryFn: () => adminClient.dashboard.operations({ channel_id: channelParam }),
    staleTime: 5 * 60 * 1000,
    placeholderData: (previousData) => previousData,
  })

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
      <AnalyticsChart data={overview} />
      <div className="grid gap-6 lg:grid-cols-5">
        <OperationsCard
          data={operations}
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

/**
 * Period-over-period delta indicator: green/red trend arrow + percentage, a
 * neutral dash at 0, and a "New" badge when there is no previous-period
 * baseline (`growth === null`).
 */
function GrowthBadge({ growth }: { growth: number | null | undefined }) {
  const { t } = useTranslation()

  if (growth === null || growth === undefined) {
    return (
      <Badge variant="secondary" title={t('admin.pages.home.growth.vs_previous')}>
        {t('admin.pages.home.growth.new')}
      </Badge>
    )
  }

  const formatted = `${growth > 0 ? '+' : ''}${growth.toLocaleString()}%`

  if (growth === 0) {
    return (
      <span
        className="inline-flex items-center gap-0.5 text-xs font-medium text-muted-foreground"
        title={t('admin.pages.home.growth.vs_previous')}
      >
        <MinusIcon className="size-3" />
        {formatted}
      </span>
    )
  }

  return (
    <span
      className={`inline-flex items-center gap-0.5 text-xs font-medium ${
        growth > 0 ? 'text-green-700 dark:text-green-400' : 'text-destructive'
      }`}
      title={t('admin.pages.home.growth.vs_previous')}
    >
      {growth > 0 ? <TrendingUpIcon className="size-3" /> : <TrendingDownIcon className="size-3" />}
      {formatted}
    </span>
  )
}

function AnalyticsChart({ data }: { data: ReportingResult }) {
  const { t, i18n } = useTranslation()
  const locale = i18n.language
  const [activeMetric, setActiveMetric] = useState<ChartMetric>('sales')

  const totalFor = (uiKey: ChartMetric) => data.totals[CHART_METRICS[uiKey]]
  const displayFor = (uiKey: ChartMetric) => {
    const total = totalFor(uiKey)
    return total?.display ?? (total?.value ?? 0).toLocaleString()
  }

  // One reporting query feeds both series: `value` is the current period,
  // `previous` the aligned bucket from the comparison period.
  const chartData = data.rows.map((row) => ({
    date: rawDimension(row, 'completed_at'),
    current: row.metrics[CHART_METRICS[activeMetric]]?.value ?? 0,
    previous: row.metrics[CHART_METRICS[activeMetric]]?.previous ?? 0,
  }))

  const chartConfig: ChartConfig = {
    current: {
      label: t(`admin.pages.home.metric_short.${activeMetric}`),
      color: 'var(--chart-2)',
    },
    previous: {
      label: t('admin.pages.home.legend.previous'),
      color: 'var(--muted-foreground)',
    },
  }

  const formatDay = (value: string) =>
    new Date(value).toLocaleDateString(locale, { month: 'short', day: 'numeric' })

  return (
    <Card>
      <CardHeader className="grid h-auto grid-cols-2 gap-0 border-b p-0 sm:grid-cols-3 lg:grid-cols-5">
        {(Object.keys(CHART_METRICS) as ChartMetric[]).map((metric) => (
          <button
            key={metric}
            type="button"
            onClick={() => setActiveMetric(metric)}
            className={`relative flex flex-col justify-center gap-1 border-b px-6 py-4 text-left lg:border-b-0 ${
              activeMetric === metric ? 'bg-muted/50' : 'hover:bg-muted/25'
            } sm:border-l sm:first:border-l-0`}
          >
            <span className="text-xs text-muted-foreground">
              {t(`admin.pages.home.metrics.${metric}`)}
            </span>
            <span className="flex items-center gap-2">
              <span className="text-lg font-bold leading-none">{displayFor(metric)}</span>
              <GrowthBadge growth={totalFor(metric)?.growth} />
            </span>
            {activeMetric === metric && (
              <span className="absolute inset-x-0 bottom-0 h-0.5 bg-primary" />
            )}
          </button>
        ))}
      </CardHeader>
      <CardContent className="px-2 pt-4 sm:px-6 sm:pt-6">
        <ChartContainer config={chartConfig} className="aspect-auto h-[250px] w-full">
          <ComposedChart data={chartData}>
            <CartesianGrid vertical={false} />
            <XAxis
              dataKey="date"
              tickLine={false}
              axisLine={false}
              tickMargin={8}
              minTickGap={32}
              tickFormatter={formatDay}
            />
            <ChartTooltip
              cursor={{ fill: 'rgba(0, 0, 0, 0.04)' }}
              content={
                <ChartTooltipContent
                  labelFormatter={(value: string) => {
                    return new Date(value).toLocaleDateString(locale, {
                      month: 'short',
                      day: 'numeric',
                      year: 'numeric',
                    })
                  }}
                />
              }
            />
            <Bar
              dataKey="current"
              fill="var(--color-current)"
              opacity={0.8}
              activeBar={{ opacity: 1 }}
              radius={[4, 4, 0, 0]}
            />
            <Line
              dataKey="previous"
              stroke="var(--color-previous)"
              strokeWidth={2}
              strokeDasharray="4 4"
              strokeOpacity={0.7}
              dot={false}
              type="monotone"
            />
          </ComposedChart>
        </ChartContainer>
        <div className="flex items-center justify-center gap-6 pb-2 pt-3 text-xs text-muted-foreground">
          <span className="inline-flex items-center gap-1.5">
            <span className="size-2.5 rounded-[2px]" style={{ background: 'var(--chart-2)' }} />
            {t('admin.pages.home.legend.current')}
          </span>
          <span className="inline-flex items-center gap-1.5">
            <span
              className="h-0 w-4 border-t-2 border-dashed"
              style={{ borderColor: 'var(--muted-foreground)' }}
            />
            {t('admin.pages.home.legend.previous')}
          </span>
        </div>
      </CardContent>
    </Card>
  )
}

const OPERATIONS_ROW_CLASS = 'flex items-center gap-3 border-b px-4 py-3 last:border-0'

type OperationsFilter = { id: string; field: string; operator: string; value: string }

const OPERATIONS_ROWS: Array<{
  key: keyof Omit<DashboardOperations, 'low_stock_threshold' | 'channel_id'>
  icon: typeof PackageIcon
  link?: { to: '/$storeId/orders' | '/$storeId/products'; filters: OperationsFilter[] }
}> = [
  {
    key: 'orders_to_fulfill',
    icon: TruckIcon,
    link: {
      to: '/$storeId/orders',
      filters: [
        // Mirrors the `ready_to_ship` scope backing the count.
        { id: 'home-fulfill', field: 'fulfillment_status', operator: 'in', value: 'ready,pending' },
      ],
    },
  },
  {
    key: 'payments_to_collect',
    icon: CreditCardIcon,
    link: {
      to: '/$storeId/orders',
      filters: [
        { id: 'home-collect', field: 'payment_status', operator: 'eq', value: 'balance_due' },
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
}: {
  data: DashboardOperations | undefined
  className: string
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
            const content = (
              <>
                <span className="flex size-8 shrink-0 items-center justify-center rounded-md border bg-muted/50">
                  <Icon className="size-4 text-muted-foreground" />
                </span>
                <span className="flex-1 text-sm">{t(`admin.pages.home.operations.${key}`)}</span>
                {count === undefined ? (
                  <Skeleton className="h-4 w-8" />
                ) : (
                  <span
                    className={`text-sm font-semibold tabular-nums ${
                      count === 0 ? 'text-muted-foreground' : ''
                    }`}
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
                  search={{ filters: link.filters }}
                  className={`${OPERATIONS_ROW_CLASS} hover:bg-muted/25`}
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
  const { data } = useReportingQuery({ ...query, ...scope })

  const rows = data?.rows.map((row) => {
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
        <div className="flex rounded-lg border p-0.5">
          {tabs.map((value) => (
            <button
              key={value}
              type="button"
              onClick={() => setTab(value)}
              className={`rounded-md px-3 py-1 text-sm ${
                tab === value ? 'bg-muted font-medium' : 'text-muted-foreground hover:bg-muted/50'
              }`}
            >
              {t(`admin.pages.home.rankings.tabs.${value}`)}
            </button>
          ))}
        </div>
      </CardHeader>
      <CardContent className="p-0">
        {rows === undefined ? (
          <RankingRowsSkeleton />
        ) : rows.length === 0 ? (
          <p className="px-4 pb-6 pt-2 text-sm text-muted-foreground">
            {t('admin.pages.home.rankings.empty')}
          </p>
        ) : (
          <div className="flex flex-col">
            {rows.map((row, index) => (
              <div key={`${tab}-${row.key}`} className="border-b px-4 py-3 last:border-0">
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
                <div className="mt-2 h-1 w-full overflow-hidden rounded-full bg-muted">
                  <div
                    className="h-full rounded-full"
                    style={{
                      background: 'var(--chart-2)',
                      width: `${maxAmount > 0 ? Math.max((row.amount / maxAmount) * 100, 2) : 0}%`,
                    }}
                  />
                </div>
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
  const email = metaString(dimension, 'email')
  const label = (
    <span className="min-w-0">
      <span className="block truncate font-medium">{dimension.label}</span>
      {email && email !== dimension.label && (
        <span className="block truncate text-xs text-muted-foreground">{email}</span>
      )}
    </span>
  )

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
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b text-left text-muted-foreground">
              <th className="px-4 py-2 font-medium">{t('admin.pages.home.columns.product')}</th>
              <th className="px-4 py-2 text-right font-medium">
                {t('admin.pages.home.columns.price')}
              </th>
              <th className="px-4 py-2 text-right font-medium">
                {t('admin.pages.home.columns.sold')}
              </th>
              <th className="px-4 py-2 text-right font-medium">{t('admin.fields.total.label')}</th>
              <th className="px-4 py-2 text-right font-medium">
                {t('admin.pages.home.columns.trend')}
              </th>
            </tr>
          </thead>
          <tbody>
            {data.rows.map((row) => {
              const product = entityDimension(row, 'product')
              const productId = product.id
              const revenue = row.metrics.net_revenue
              const thumbnail = metaString(product, 'thumbnail_url') ?? null
              const price = metaString(product, 'price')

              return (
                <tr key={productId ?? product.label} className="border-b last:border-0">
                  <td className="px-4 py-3">
                    {productId ? (
                      <Link
                        to="/$storeId/products/$productId"
                        params={{ storeId, productId }}
                        className="flex items-center gap-3 hover:underline"
                      >
                        <ProductThumbnail thumbnail={thumbnail} label={product.label} />
                        <span className="font-medium">{product.label}</span>
                      </Link>
                    ) : (
                      <span className="flex items-center gap-3">
                        <ProductThumbnail thumbnail={thumbnail} label={product.label} />
                        <span className="font-medium">{product.label}</span>
                      </span>
                    )}
                  </td>
                  <td className="px-4 py-3 text-right text-muted-foreground">{price ?? '-'}</td>
                  <td className="px-4 py-3 text-right">{row.metrics.units_sold?.value ?? 0}</td>
                  <td className="px-4 py-3 text-right font-medium">
                    {revenue?.display ?? revenue?.value}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <GrowthBadge growth={revenue?.growth} />
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </CardContent>
    </Card>
  )
}

function ProductThumbnail({ thumbnail, label }: { thumbnail: string | null; label: string }) {
  if (thumbnail) {
    return <img src={thumbnail} alt={label} className="size-10 rounded-md border object-cover" />
  }
  return (
    <div className="flex size-10 items-center justify-center rounded-md border bg-muted">
      <PackageIcon className="size-4 text-muted-foreground" />
    </div>
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
      <Card>
        <CardHeader className="grid h-auto grid-cols-2 gap-0 border-b p-0 sm:grid-cols-3 lg:grid-cols-5">
          {['stat-1', 'stat-2', 'stat-3', 'stat-4', 'stat-5'].map((key) => (
            <div
              key={key}
              className="flex flex-col gap-2 px-6 py-4 sm:border-l sm:first:border-l-0"
            >
              <Skeleton className="h-3 w-20" />
              <Skeleton className="h-7 w-28" />
            </div>
          ))}
        </CardHeader>
        <CardContent className="px-2 pt-4 sm:px-6 sm:pt-6">
          <Skeleton className="h-[250px] w-full" />
        </CardContent>
      </Card>
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
