import type { DashboardAnalytics, DashboardOperations, DashboardRankings } from '@spree/admin-sdk'
import { adminClient } from '@spree/dashboard-core'
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
import { Fragment, type ReactNode, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Bar, CartesianGrid, ComposedChart, Line, XAxis } from 'recharts'

export const Route = createFileRoute('/_authenticated/$storeId/')({
  component: DashboardPage,
})

type ChartMetric = 'sales' | 'orders' | 'avg_order_value' | 'units' | 'customers'

const CHART_METRICS: ChartMetric[] = ['sales', 'orders', 'avg_order_value', 'units', 'customers']

function DashboardPage() {
  const { t } = useTranslation()
  const [dateRange, setDateRange] = useState<DateRange>({
    from: subDays(new Date(), 30),
    to: new Date(),
  })

  const rangeParams = {
    date_from: dateRange.from.toISOString(),
    date_to: dateRange.to.toISOString(),
  }

  const { data: analytics } = useQuery({
    queryKey: ['dashboard', 'analytics', rangeParams.date_from, rangeParams.date_to],
    queryFn: () => adminClient.dashboard.analytics(rangeParams),
    staleTime: 5 * 60 * 1000,
    placeholderData: (previousData) => previousData,
  })

  const { data: rankings } = useQuery({
    queryKey: ['dashboard', 'rankings', rangeParams.date_from, rangeParams.date_to],
    queryFn: () => adminClient.dashboard.rankings(rangeParams),
    staleTime: 5 * 60 * 1000,
    placeholderData: (previousData) => previousData,
  })

  const { data: operations } = useQuery({
    queryKey: ['dashboard', 'operations'],
    queryFn: () => adminClient.dashboard.operations(),
    staleTime: 5 * 60 * 1000,
  })

  if (!analytics) {
    return <DashboardSkeleton />
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">{t('admin.pages.home.title')}</h1>
          <p className="text-muted-foreground">{t('admin.pages.home.subtitle')}</p>
        </div>
        <DateRangePicker value={dateRange} onChange={setDateRange} />
      </div>
      <AnalyticsChart data={analytics} />
      <div className="grid gap-6 lg:grid-cols-5">
        <OperationsCard data={operations} />
        <RankingsCard data={rankings} />
      </div>
      <TopProducts products={analytics.top_products} />
    </div>
  )
}

/**
 * Period-over-period delta indicator: green/red trend arrow + percentage, a
 * neutral dash at 0, and a "New" badge when there is no previous-period
 * baseline (`growth === null`).
 */
function GrowthBadge({ growth }: { growth: number | null }) {
  const { t } = useTranslation()

  if (growth === null) {
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

function AnalyticsChart({ data }: { data: DashboardAnalytics }) {
  const { t, i18n } = useTranslation()
  const locale = i18n.language
  const [activeMetric, setActiveMetric] = useState<ChartMetric>('sales')

  const summaryValues: Record<ChartMetric, string> = {
    sales: data.summary.display_sales_total,
    orders: data.summary.orders_count.toLocaleString(),
    avg_order_value: data.summary.display_avg_order_value,
    units: data.summary.units_sold.toLocaleString(),
    customers: data.summary.customers_count.toLocaleString(),
  }

  const growthValues: Record<ChartMetric, number | null> = {
    sales: data.summary.sales_growth,
    orders: data.summary.orders_growth,
    avg_order_value: data.summary.avg_order_value_growth,
    units: data.summary.units_growth,
    customers: data.summary.customers_growth,
  }

  const chartConfig: ChartConfig = {
    [activeMetric]: {
      label: t(`admin.pages.home.metric_short.${activeMetric}`),
      color: 'var(--chart-2)',
    },
    [`previous_${activeMetric}`]: {
      label: t('admin.pages.home.legend.previous'),
      color: 'var(--muted-foreground)',
    },
  }

  const formatDay = (value: string) =>
    new Date(value).toLocaleDateString(locale, { month: 'short', day: 'numeric' })

  return (
    <Card>
      <CardHeader className="grid h-auto grid-cols-2 gap-0 border-b p-0 sm:grid-cols-3 lg:grid-cols-5">
        {CHART_METRICS.map((metric) => (
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
              <span className="text-lg font-bold leading-none">{summaryValues[metric]}</span>
              <GrowthBadge growth={growthValues[metric]} />
            </span>
            {activeMetric === metric && (
              <span className="absolute inset-x-0 bottom-0 h-0.5 bg-primary" />
            )}
          </button>
        ))}
      </CardHeader>
      <CardContent className="px-2 pt-4 sm:px-6 sm:pt-6">
        <ChartContainer config={chartConfig} className="aspect-auto h-[250px] w-full">
          <ComposedChart data={data.chart_data}>
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
              dataKey={activeMetric}
              fill={`var(--color-${activeMetric})`}
              opacity={0.8}
              activeBar={{ opacity: 1 }}
              radius={[4, 4, 0, 0]}
            />
            <Line
              dataKey={`previous_${activeMetric}`}
              stroke={`var(--color-previous_${activeMetric})`}
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

function OperationsCard({ data }: { data: DashboardOperations | undefined }) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()

  const rowClass = `${OPERATIONS_ROW_CLASS} hover:bg-muted/25`
  const rows: Array<{
    key: keyof Omit<DashboardOperations, 'low_stock_threshold'>
    icon: typeof PackageIcon
    wrap?: (children: ReactNode) => ReactNode
  }> = [
    {
      key: 'orders_to_fulfill',
      icon: TruckIcon,
      wrap: (children) => (
        <Link
          to="/$storeId/orders"
          params={{ storeId }}
          search={{
            filters: [
              {
                id: 'home-fulfill',
                field: 'fulfillment_status',
                operator: 'in',
                value: 'ready,pending',
              },
            ],
          }}
          className={rowClass}
        >
          {children}
        </Link>
      ),
    },
    {
      key: 'payments_to_collect',
      icon: CreditCardIcon,
      wrap: (children) => (
        <Link
          to="/$storeId/orders"
          params={{ storeId }}
          search={{
            filters: [
              { id: 'home-collect', field: 'payment_status', operator: 'eq', value: 'balance_due' },
            ],
          }}
          className={rowClass}
        >
          {children}
        </Link>
      ),
    },
    { key: 'open_returns', icon: RotateCcwIcon },
    { key: 'low_stock_items', icon: TriangleAlertIcon },
    {
      key: 'out_of_stock_items',
      icon: PackageXIcon,
      wrap: (children) => (
        <Link
          to="/$storeId/products"
          params={{ storeId }}
          search={{
            filters: [{ id: 'home-oos', field: 'in_stock', operator: 'eq', value: 'false' }],
          }}
          className={rowClass}
        >
          {children}
        </Link>
      ),
    },
  ]

  return (
    <Card className="lg:col-span-2">
      <CardHeader>
        <CardTitle>{t('admin.pages.home.operations.title')}</CardTitle>
        <CardDescription>{t('admin.pages.home.operations.subtitle')}</CardDescription>
      </CardHeader>
      <CardContent className="p-0">
        <div className="flex flex-col">
          {rows.map(({ key, icon: Icon, wrap }) => {
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
                {wrap && <ChevronRightIcon className="size-4 text-muted-foreground" />}
              </>
            )

            if (wrap) {
              return <Fragment key={key}>{wrap(content)}</Fragment>
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

function RankingsCard({ data }: { data: DashboardRankings | undefined }) {
  const { t } = useTranslation()
  const [tab, setTab] = useState<RankingTab>('customers')

  const items = data?.[tab]
  const maxAmount = items?.length ? Math.max(...items.map((item) => item.amount)) : 0

  return (
    <Card className="lg:col-span-3">
      <CardHeader className="flex flex-row items-start justify-between gap-4">
        <div className="flex flex-col gap-1.5">
          <CardTitle>{t('admin.pages.home.rankings.title')}</CardTitle>
          <CardDescription>{t('admin.pages.home.rankings.subtitle')}</CardDescription>
        </div>
        <div className="flex rounded-lg border p-0.5">
          {(['customers', 'categories'] as RankingTab[]).map((value) => (
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
        {items === undefined ? (
          <RankingRowsSkeleton />
        ) : items.length === 0 ? (
          <p className="px-4 pb-6 pt-2 text-sm text-muted-foreground">
            {t('admin.pages.home.rankings.empty')}
          </p>
        ) : (
          <div className="flex flex-col">
            {items.map((item, index) => (
              <div key={`${tab}-${item.id ?? index}`} className="border-b px-4 py-3 last:border-0">
                <div className="flex items-baseline justify-between gap-3">
                  <span className="flex min-w-0 items-baseline gap-2 text-sm">
                    <span className="w-5 shrink-0 text-muted-foreground tabular-nums">
                      {index + 1}.
                    </span>
                    <RankingName tab={tab} item={item} />
                  </span>
                  <span className="shrink-0 text-right">
                    <span className="block text-sm font-medium tabular-nums">
                      {item.display_amount}
                    </span>
                    <span className="block text-xs text-muted-foreground">
                      {tab === 'customers'
                        ? t('admin.pages.home.rankings.orders_count', {
                            count: (item as DashboardRankings['customers'][number]).orders_count,
                          })
                        : t('admin.pages.home.rankings.units_count', {
                            count: (item as DashboardRankings['categories'][number]).quantity,
                          })}
                    </span>
                  </span>
                </div>
                <div className="mt-2 h-1 w-full overflow-hidden rounded-full bg-muted">
                  <div
                    className="h-full rounded-full"
                    style={{
                      background: 'var(--chart-2)',
                      width: `${maxAmount > 0 ? Math.max((item.amount / maxAmount) * 100, 2) : 0}%`,
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
  item,
}: {
  tab: RankingTab
  item: DashboardRankings['customers'][number] | DashboardRankings['categories'][number]
}) {
  const { storeId } = Route.useParams()

  if (tab === 'customers') {
    const customer = item as DashboardRankings['customers'][number]
    const label = (
      <span className="min-w-0">
        <span className="block truncate font-medium">{customer.name}</span>
        {customer.name !== customer.email && (
          <span className="block truncate text-xs text-muted-foreground">{customer.email}</span>
        )}
      </span>
    )
    if (customer.id) {
      return (
        <Link
          to="/$storeId/customers/$customerId"
          params={{ storeId, customerId: customer.id }}
          className="min-w-0 hover:underline"
        >
          {label}
        </Link>
      )
    }
    return label
  }

  const category = item as DashboardRankings['categories'][number]
  return (
    <Link
      to="/$storeId/products/categories/$categoryId"
      params={{ storeId, categoryId: category.id }}
      className="min-w-0 truncate font-medium hover:underline"
    >
      {category.name}
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

function TopProducts({ products }: { products: DashboardAnalytics['top_products'] }) {
  const { t } = useTranslation()
  if (products.length === 0) {
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
            {products.map((product) => (
              <tr key={product.id} className="border-b last:border-0">
                <td className="px-4 py-3">
                  <Link
                    to="/$storeId/products/$productId"
                    params={(prev) => ({
                      storeId: prev.storeId!,
                      productId: product.id,
                    })}
                    className="flex items-center gap-3 hover:underline"
                  >
                    {product.image_url ? (
                      <img
                        src={product.image_url}
                        alt={product.name}
                        className="size-10 rounded-md border object-cover"
                      />
                    ) : (
                      <div className="flex size-10 items-center justify-center rounded-md border bg-muted">
                        <PackageIcon className="size-4 text-muted-foreground" />
                      </div>
                    )}
                    <span className="font-medium">{product.name}</span>
                  </Link>
                </td>
                <td className="px-4 py-3 text-right text-muted-foreground">
                  {product.price ?? '-'}
                </td>
                <td className="px-4 py-3 text-right">{product.quantity}</td>
                <td className="px-4 py-3 text-right font-medium">{product.total}</td>
                <td className="px-4 py-3 text-right">
                  <GrowthBadge growth={product.growth} />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
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
              {['op-1', 'op-2', 'op-3', 'op-4', 'op-5', 'op-6'].map((key) => (
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
