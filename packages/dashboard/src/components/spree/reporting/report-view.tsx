import type {
  ReportingDimensionValue,
  ReportingGrain,
  ReportingMetricValue,
  ReportingQuery,
  ReportingResult,
  ReportingRow,
  ReportingSchema,
  ReportingSchemaMetric,
} from '@spree/admin-sdk'
import {
  Card,
  CardContent,
  CardHeader,
  type ChartConfig,
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
  cn,
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
} from '@spree/dashboard-ui'
import { ChartColumnIcon, TriangleAlertIcon } from '@spree/dashboard-ui/icons'
import { memo, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Bar, CartesianGrid, ComposedChart, Line, XAxis } from 'recharts'
import { entityDimension, metaString, rawDimension } from '../../../hooks/use-reporting'
import { GrowthBadge } from './growth-badge'
import { inferViz, queryDimension } from './report-draft'

interface ReportViewProps {
  query: ReportingQuery
  schema: ReportingSchema
  result: ReportingResult | undefined
  error?: Error | null
}

/**
 * Renders a reporting result in the visualization its query shape implies
 * (see `inferViz`). Shape-generic on purpose: any saved report — and any
 * future client of the contract — renders through it, so nothing here knows
 * metric or dimension names.
 */
export const ReportView = memo(function ReportView({
  query,
  schema,
  result,
  error,
}: ReportViewProps) {
  const { t } = useTranslation()
  const viz = inferViz(query, schema)
  const compare = query.compare === 'previous_period'
  const metrics = useMemo(() => resolveMetrics(query.metrics, schema), [query.metrics, schema])

  if (error) {
    return (
      <Card>
        <CardContent>
          <Empty>
            <EmptyHeader>
              <EmptyMedia variant="icon">
                <TriangleAlertIcon />
              </EmptyMedia>
              <EmptyTitle>{t('admin.reports.view.error')}</EmptyTitle>
              <EmptyDescription>{error.message}</EmptyDescription>
            </EmptyHeader>
          </Empty>
        </CardContent>
      </Card>
    )
  }

  if (!result) {
    return <ReportSkeleton />
  }

  if (viz === 'stats') {
    return <StatTiles metrics={metrics} result={result} compare={compare} />
  }

  const dimension = queryDimension(query)
  if (!dimension) return null
  const dimensionLabel =
    schema.dimensions.find((d) => d.name === dimension.name)?.label ?? dimension.name

  if (result.rows.length === 0) {
    return (
      <Card>
        <CardContent>
          <Empty>
            <EmptyHeader>
              <EmptyMedia variant="icon">
                <ChartColumnIcon />
              </EmptyMedia>
              <EmptyTitle>{t('admin.reports.view.empty')}</EmptyTitle>
            </EmptyHeader>
          </Empty>
        </CardContent>
      </Card>
    )
  }

  if (viz === 'chart') {
    return (
      <div className="flex flex-col gap-6">
        <TimeSeriesChart
          metrics={metrics}
          result={result}
          dimension={dimension.name}
          grain={dimension.grain ?? 'day'}
          compare={compare}
        />
        <ResultTable
          rows={result.rows}
          totals={result.totals}
          metrics={metrics}
          dimensionLabel={dimensionLabel}
          renderLabel={(row) => (
            <BucketLabel
              value={rawDimension(row, dimension.name)}
              grain={dimension.grain ?? 'day'}
            />
          )}
          compare={compare}
        />
      </div>
    )
  }

  return (
    <ResultTable
      rows={result.rows}
      totals={result.totals}
      metrics={metrics}
      dimensionLabel={dimensionLabel}
      renderLabel={(row) => <EntityLabel row={row} dimension={dimension.name} />}
      compare={compare}
      ranked
    />
  )
})

/**
 * Metric definitions in the order asked for, falling back to a bare label for
 * one the schema does not describe (a saved report referencing a member the
 * viewer cannot read).
 */
export function resolveMetrics(names: string[], schema: ReportingSchema): ReportingSchemaMetric[] {
  const byName = new Map(schema.metrics.map((metric) => [metric.name, metric]))
  return names.map(
    (name) => byName.get(name) ?? { name, label: name, format: 'decimal', derived: false },
  )
}

/** Formatted metric value: the server's money display when present, else a locale number. */
export function formatMetric(
  value: ReportingMetricValue | undefined,
  metric: ReportingSchemaMetric,
  locale: string,
): string {
  if (!value) return '—'
  if (value.display) return value.display
  return value.value.toLocaleString(locale, {
    maximumFractionDigits: metric.format === 'integer' ? 0 : 2,
  })
}

/** Label, formatted total and (when comparing) the period-over-period delta. */
function MetricTile({
  metric,
  total,
  compare,
  size = 'md',
}: {
  metric: ReportingSchemaMetric
  total: ReportingMetricValue | undefined
  compare: boolean
  size?: 'md' | 'lg'
}) {
  const { i18n } = useTranslation()
  return (
    <>
      <span className="text-xs text-muted-foreground">{metric.label}</span>
      <span className="flex items-center gap-2">
        <span
          className={cn(
            'font-bold leading-none tabular-nums',
            size === 'lg' ? 'text-2xl' : 'text-lg',
          )}
        >
          {formatMetric(total, metric, i18n.language)}
        </span>
        {compare && <GrowthBadge growth={total?.growth} />}
      </span>
    </>
  )
}

function StatTiles({
  metrics,
  result,
  compare,
}: {
  metrics: ReportingSchemaMetric[]
  result: ReportingResult
  compare: boolean
}) {
  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      {metrics.map((metric) => (
        <Card key={metric.name}>
          <CardContent className="flex flex-col gap-1 py-5">
            <MetricTile
              metric={metric}
              total={result.totals[metric.name]}
              compare={compare}
              size="lg"
            />
          </CardContent>
        </Card>
      ))}
    </div>
  )
}

const BUCKET_FORMATS: Record<ReportingGrain, Intl.DateTimeFormatOptions> = {
  day: { month: 'short', day: 'numeric' },
  week: { month: 'short', day: 'numeric' },
  month: { month: 'short', year: 'numeric' },
}

export function formatBucket(value: string, grain: ReportingGrain, locale: string, long = false) {
  // Buckets arrive as store-local dates (`yyyy-MM-dd`); parsing them as UTC
  // midnight keeps the day stable whatever the browser's zone.
  const date = new Date(value.length === 10 ? `${value}T00:00:00Z` : value)
  if (Number.isNaN(date.getTime())) return value
  const options: Intl.DateTimeFormatOptions = {
    ...BUCKET_FORMATS[grain],
    ...(long && grain !== 'month' ? { year: 'numeric' } : {}),
    timeZone: 'UTC',
  }
  return date.toLocaleDateString(locale, options)
}

function BucketLabel({ value, grain }: { value: string; grain: ReportingGrain }) {
  const { i18n } = useTranslation()
  return <span className="tabular-nums">{formatBucket(value, grain, i18n.language, true)}</span>
}

/**
 * A hydrated dimension's name, with its email on a second line when the two
 * differ (a customer known by both). Shared with the home rankings.
 */
export function DimensionLabel({ dimension }: { dimension: ReportingDimensionValue }) {
  const email = metaString(dimension, 'email')

  return (
    <span className="min-w-0">
      <span className="block truncate font-medium">{dimension.label}</span>
      {email && email !== dimension.label && (
        <span className="block truncate text-xs text-muted-foreground">{email}</span>
      )}
    </span>
  )
}

/** Share of the largest value in the set, floored so a tiny bar stays visible. */
export function sharePercent(value: number, max: number): number {
  return max > 0 ? Math.max((value / max) * 100, 2) : 0
}

function EntityLabel({ row, dimension }: { row: ReportingRow; dimension: string }) {
  return <DimensionLabel dimension={entityDimension(row, dimension)} />
}

export function TimeSeriesChart({
  metrics,
  result,
  dimension,
  grain,
  compare,
}: {
  metrics: ReportingSchemaMetric[]
  result: ReportingResult
  dimension: string
  grain: ReportingGrain
  compare: boolean
}) {
  const { t, i18n } = useTranslation()
  const locale = i18n.language
  const [activeName, setActiveName] = useState(metrics[0]?.name)
  const active = metrics.find((metric) => metric.name === activeName) ?? metrics[0]

  // Recharts re-renders the whole chart on a new `data` identity, so both are
  // rebuilt only when the rows or the selected metric change.
  const chartData = useMemo(
    () =>
      result.rows.map((row) => ({
        bucket: rawDimension(row, dimension),
        current: row.metrics[active.name]?.value ?? 0,
        previous: row.metrics[active.name]?.previous ?? 0,
      })),
    [result.rows, dimension, active.name],
  )

  const chartConfig: ChartConfig = useMemo(
    () => ({
      current: { label: active.label, color: 'var(--chart-2)' },
      previous: { label: t('admin.pages.home.legend.previous'), color: 'var(--muted-foreground)' },
    }),
    [active.label, t],
  )

  const columns = Math.min(metrics.length, 5)

  return (
    <Card>
      <CardHeader
        className="grid h-auto gap-0 border-b p-0"
        style={{ gridTemplateColumns: `repeat(${columns}, minmax(0, 1fr))` }}
      >
        {metrics.map((metric) => (
          <button
            key={metric.name}
            type="button"
            onClick={() => setActiveName(metric.name)}
            className={cn(
              'relative flex flex-col justify-center gap-1 border-l px-6 py-4 text-left first:border-l-0',
              active.name === metric.name ? 'bg-muted/50' : 'hover:bg-muted/25',
            )}
          >
            <MetricTile metric={metric} total={result.totals[metric.name]} compare={compare} />
            {active.name === metric.name && (
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
              dataKey="bucket"
              tickLine={false}
              axisLine={false}
              tickMargin={8}
              minTickGap={32}
              tickFormatter={(value: string) => formatBucket(value, grain, locale)}
            />
            <ChartTooltip
              cursor={{ fill: 'rgba(0, 0, 0, 0.04)' }}
              content={
                <ChartTooltipContent
                  labelFormatter={(value: string) => formatBucket(value, grain, locale, true)}
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
            {compare && (
              <Line
                dataKey="previous"
                stroke="var(--color-previous)"
                strokeWidth={2}
                strokeDasharray="4 4"
                strokeOpacity={0.7}
                dot={false}
                type="monotone"
              />
            )}
          </ComposedChart>
        </ChartContainer>
        {compare && (
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
        )}
      </CardContent>
    </Card>
  )
}

function ResultTable({
  rows,
  totals,
  metrics,
  dimensionLabel,
  renderLabel,
  compare,
  ranked = false,
}: {
  rows: ReportingRow[]
  totals: ReportingResult['totals']
  metrics: ReportingSchemaMetric[]
  dimensionLabel: string
  renderLabel: (row: ReportingRow) => React.ReactNode
  compare: boolean
  ranked?: boolean
}) {
  const { t, i18n } = useTranslation()
  const locale = i18n.language
  // The first metric doubles as the share bar on a ranking, like the home rankings.
  const shareMetric = ranked ? metrics[0] : undefined
  const maxShare = shareMetric
    ? Math.max(...rows.map((row) => row.metrics[shareMetric.name]?.value ?? 0), 0)
    : 0

  return (
    <Card>
      <CardContent className="p-0">
        <Table data-testid="report-table" roundedBottom>
          <TableHeader>
            <TableHeaderRow>
              {ranked && <TableHead className="w-10">#</TableHead>}
              <TableHead>{dimensionLabel}</TableHead>
              {metrics.map((metric) => (
                <TableHead key={metric.name} className="text-right">
                  {metric.label}
                </TableHead>
              ))}
              {compare && (
                <TableHead className="text-right">{t('admin.reports.view.change')}</TableHead>
              )}
            </TableHeaderRow>
          </TableHeader>
          <TableBody>
            {rows.map((row, index) => {
              const share = shareMetric ? (row.metrics[shareMetric.name]?.value ?? 0) : 0
              return (
                <TableRow key={JSON.stringify(row.dimensions)}>
                  {ranked && (
                    <TableCell className="text-muted-foreground tabular-nums">
                      {index + 1}.
                    </TableCell>
                  )}
                  <TableCell>
                    {renderLabel(row)}
                    {shareMetric && (
                      <Progress className="mt-2 max-w-xs" value={sharePercent(share, maxShare)} />
                    )}
                  </TableCell>
                  {metrics.map((metric) => (
                    <TableCell key={metric.name} className="text-right tabular-nums">
                      {formatMetric(row.metrics[metric.name], metric, locale)}
                    </TableCell>
                  ))}
                  {compare && (
                    <TableCell className="text-right">
                      <GrowthBadge growth={row.metrics[metrics[0]?.name]?.growth} />
                    </TableCell>
                  )}
                </TableRow>
              )
            })}
            <TableRow className="bg-muted/30 font-medium">
              {ranked && <TableCell />}
              <TableCell>{t('admin.reports.view.total')}</TableCell>
              {metrics.map((metric) => (
                <TableCell key={metric.name} className="text-right tabular-nums">
                  {formatMetric(totals[metric.name], metric, locale)}
                </TableCell>
              ))}
              {compare && (
                <TableCell className="text-right">
                  <GrowthBadge growth={totals[metrics[0]?.name]?.growth} />
                </TableCell>
              )}
            </TableRow>
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  )
}

export function ReportSkeleton() {
  return (
    <Card>
      <CardHeader className="grid h-auto grid-cols-2 gap-0 border-b p-0 sm:grid-cols-4">
        {['a', 'b', 'c', 'd'].map((key) => (
          <div key={key} className="flex flex-col gap-2 px-6 py-4 sm:border-l sm:first:border-l-0">
            <Skeleton className="h-3 w-20" />
            <Skeleton className="h-7 w-28" />
          </div>
        ))}
      </CardHeader>
      <CardContent className="px-2 pt-4 sm:px-6 sm:pt-6">
        <Skeleton className="h-[250px] w-full" />
      </CardContent>
    </Card>
  )
}
