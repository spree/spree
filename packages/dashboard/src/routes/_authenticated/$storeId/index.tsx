import type { DashboardAnalytics } from '@spree/admin-sdk'
import { adminClient } from '@spree/dashboard-core'
import {
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
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  Thumbnail,
} from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { createFileRoute, Link } from '@tanstack/react-router'
import { subDays } from 'date-fns'
import { PackageIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Bar, BarChart, CartesianGrid, XAxis } from 'recharts'

export const Route = createFileRoute('/_authenticated/$storeId/')({
  component: DashboardPage,
})

type ChartMetric = 'sales' | 'orders' | 'avg_order_value'

const CHART_METRICS: ChartMetric[] = ['sales', 'orders', 'avg_order_value']

function DashboardPage() {
  const { t } = useTranslation()
  const [dateRange, setDateRange] = useState<DateRange>({
    from: subDays(new Date(), 30),
    to: new Date(),
  })

  const { data } = useQuery({
    queryKey: ['dashboard', 'analytics', dateRange.from.toISOString(), dateRange.to.toISOString()],
    queryFn: () =>
      adminClient.dashboard.analytics({
        date_from: dateRange.from.toISOString(),
        date_to: dateRange.to.toISOString(),
      }),
    staleTime: 5 * 60 * 1000,
    placeholderData: (previousData) => previousData,
  })

  if (!data) {
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
      <AnalyticsChart data={data} />
      <TopProducts products={data.top_products} />
    </div>
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
  }

  const chartConfig: ChartConfig = {
    [activeMetric]: {
      label: t(`admin.pages.home.metric_short.${activeMetric}`),
      color: 'var(--chart-2)',
    },
  }

  return (
    <Card>
      <CardHeader className="flex h-auto flex-row border-b p-0 gap-0">
        {CHART_METRICS.map((metric) => (
          <button
            key={metric}
            type="button"
            onClick={() => setActiveMetric(metric)}
            className="relative flex min-w-0 flex-1 flex-col justify-center gap-1 border-l px-3 py-3 text-left transition-colors first:border-l-0 hover:bg-muted/40 sm:px-6 sm:py-4"
          >
            <span className="truncate text-xs text-muted-foreground">
              {t(`admin.pages.home.metrics.${metric}`)}
            </span>
            <span className="truncate text-base font-bold leading-none sm:text-lg">
              {summaryValues[metric]}
            </span>
            {activeMetric === metric && (
              <span className="absolute inset-x-0 bottom-0 h-0.5 bg-primary" />
            )}
          </button>
        ))}
      </CardHeader>
      <CardContent className="px-2 pt-4 sm:px-6 sm:pt-6">
        <ChartContainer config={chartConfig} className="aspect-auto h-[250px] w-full">
          <BarChart data={data.chart_data}>
            <CartesianGrid vertical={false} />
            <XAxis
              dataKey="date"
              tickLine={false}
              axisLine={false}
              tickMargin={8}
              minTickGap={32}
              tickFormatter={(value: string) => {
                const date = new Date(value)
                return date.toLocaleDateString(locale, { month: 'short', day: 'numeric' })
              }}
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
          </BarChart>
        </ChartContainer>
      </CardContent>
    </Card>
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
        <Table roundedBottom>
          <TableHeader>
            <TableRow>
              <TableHead>{t('admin.pages.home.columns.product')}</TableHead>
              <TableHead className="text-right">{t('admin.pages.home.columns.price')}</TableHead>
              <TableHead className="text-right">{t('admin.pages.home.columns.sold')}</TableHead>
              <TableHead className="text-right">{t('admin.fields.total.label')}</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {products.map((product) => (
              <TableRow key={product.id}>
                <TableCell>
                  <Link
                    to="/$storeId/products/$productId"
                    params={(prev) => ({
                      storeId: prev.storeId!,
                      productId: product.id,
                    })}
                    className="flex items-center gap-3 hover:underline"
                  >
                    <Thumbnail src={product.image_url} fallback={<PackageIcon />} />
                    <span className="font-medium">{product.name}</span>
                  </Link>
                </TableCell>
                <TableCell className="text-right text-muted-foreground tabular-nums">
                  {product.price ?? '-'}
                </TableCell>
                <TableCell className="text-right tabular-nums">{product.quantity}</TableCell>
                <TableCell className="text-right font-medium tabular-nums">
                  {product.total}
                </TableCell>
              </TableRow>
            ))}
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
      <Card>
        <CardHeader className="flex h-auto flex-col border-b p-0 sm:flex-row">
          {['stat-1', 'stat-2', 'stat-3'].map((key) => (
            <div
              key={key}
              className="flex flex-1 flex-col gap-2 px-6 py-4 sm:border-l sm:first:border-l-0"
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
      <Card>
        <CardHeader>
          <Skeleton className="h-5 w-32" />
          <Skeleton className="h-4 w-56" />
        </CardHeader>
        <CardContent className="p-0">
          <div className="flex flex-col">
            {['row-1', 'row-2', 'row-3', 'row-4', 'row-5'].map((key) => (
              <div key={key} className="flex items-center gap-3 border-b px-4 py-3 last:border-0">
                <Skeleton className="size-10 rounded-md" />
                <Skeleton className="h-4 w-32 flex-1" />
                <Skeleton className="h-4 w-16" />
                <Skeleton className="h-4 w-12" />
                <Skeleton className="h-4 w-20" />
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
