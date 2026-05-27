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

const chartTabs: Array<{ key: ChartMetric; label: string }> = [
  { key: 'sales', label: 'Total Sales' },
  { key: 'orders', label: 'Total Orders' },
  { key: 'avg_order_value', label: 'Avg Order Value' },
]

const chartConfigs: Record<ChartMetric, ChartConfig> = {
  sales: {
    sales: { label: 'Sales', color: 'var(--chart-2)' },
  },
  orders: {
    orders: { label: 'Orders', color: 'var(--chart-2)' },
  },
  avg_order_value: {
    avg_order_value: { label: 'AOV', color: 'var(--chart-2)' },
  },
}

function DashboardPage() {
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
          <h1 className="text-2xl font-bold">Dashboard</h1>
          <p className="text-muted-foreground">Overview of your store performance</p>
        </div>
        <DateRangePicker value={dateRange} onChange={setDateRange} />
      </div>
      <AnalyticsChart data={data} />
      <TopProducts products={data.top_products} />
    </div>
  )
}

function AnalyticsChart({ data }: { data: DashboardAnalytics }) {
  const [activeMetric, setActiveMetric] = useState<ChartMetric>('sales')

  const summaryValues: Record<ChartMetric, string> = {
    sales: data.summary.display_sales_total,
    orders: data.summary.orders_count.toLocaleString(),
    avg_order_value: data.summary.display_avg_order_value,
  }

  return (
    <Card>
      <CardHeader className="flex h-auto flex-col border-b p-0 sm:flex-row gap-0">
        {chartTabs.map((tab) => (
          <button
            key={tab.key}
            type="button"
            onClick={() => setActiveMetric(tab.key)}
            className={`relative flex flex-1 flex-col justify-center gap-1 px-6 py-4 text-left ${
              activeMetric === tab.key ? 'bg-muted/50' : 'hover:bg-muted/25'
            } sm:border-l sm:first:border-l-0`}
          >
            <span className="text-xs text-muted-foreground">{tab.label}</span>
            <span className="text-lg font-bold leading-none">{summaryValues[tab.key]}</span>
            {activeMetric === tab.key && (
              <span className="absolute inset-x-0 bottom-0 h-0.5 bg-primary" />
            )}
          </button>
        ))}
      </CardHeader>
      <CardContent className="px-2 pt-4 sm:px-6 sm:pt-6">
        <ChartContainer
          config={chartConfigs[activeMetric]}
          className="aspect-auto h-[250px] w-full"
        >
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
                return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
              }}
            />
            <ChartTooltip
              cursor={{ fill: 'rgba(0, 0, 0, 0.04)' }}
              content={
                <ChartTooltipContent
                  labelFormatter={(value: string) => {
                    return new Date(value).toLocaleDateString('en-US', {
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
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b text-left text-muted-foreground">
              <th className="px-4 py-2 font-medium">Product</th>
              <th className="px-4 py-2 text-right font-medium">Price</th>
              <th className="px-4 py-2 text-right font-medium">Sold</th>
              <th className="px-4 py-2 text-right font-medium">Total</th>
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
              </tr>
            ))}
          </tbody>
        </table>
      </CardContent>
    </Card>
  )
}

function DashboardSkeleton() {
  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-2xl font-bold">Dashboard</h1>
        <p className="text-muted-foreground">Overview of your store performance</p>
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
