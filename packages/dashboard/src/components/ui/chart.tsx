import * as React from 'react'
import { ResponsiveContainer, Tooltip } from 'recharts'
import { cn } from '@/lib/utils'

export type ChartConfig = Record<string, { label: string; color?: string }>

interface ChartContextValue {
  config: ChartConfig
}

const ChartContext = React.createContext<ChartContextValue | null>(null)

export function useChart() {
  const ctx = React.useContext(ChartContext)
  if (!ctx) throw new Error('useChart must be used within ChartContainer')
  return ctx
}

export function ChartContainer({
  config,
  className,
  children,
  ...props
}: React.ComponentProps<'div'> & { config: ChartConfig }) {
  const cssVars = Object.entries(config).reduce(
    (acc, [key, value]) => {
      if (value.color) acc[`--color-${key}` as string] = value.color
      return acc
    },
    {} as Record<string, string>,
  )

  return (
    <ChartContext.Provider value={{ config }}>
      <div
        data-slot="chart"
        className={cn(
          "flex justify-center text-xs [&_.recharts-cartesian-grid_line[stroke='#ccc']]:stroke-border/50 [&_.recharts-dot[stroke='#fff']]:stroke-transparent [&_.recharts-layer]:outline-hidden [&_.recharts-sector[stroke='#fff']]:stroke-transparent [&_.recharts-sector]:outline-hidden [&_.recharts-surface]:outline-hidden",
          className,
        )}
        style={cssVars}
        {...props}
      >
        <ResponsiveContainer>{children}</ResponsiveContainer>
      </div>
    </ChartContext.Provider>
  )
}

export const ChartTooltip = Tooltip

export function ChartTooltipContent({
  active,
  payload,
  label,
  className,
  labelFormatter,
}: {
  active?: boolean
  payload?: Array<{ dataKey?: string; name?: string; value?: number | string; color?: string }>
  label?: string
  className?: string
  nameKey?: string
  labelFormatter?: (label: string) => string
}) {
  const { config } = useChart()
  if (!active || !payload?.length) return null

  const formattedLabel = labelFormatter ? labelFormatter(label ?? '') : label

  return (
    <div className={cn('rounded-lg border bg-background px-3 py-2 text-sm shadow-md', className)}>
      <div className="mb-1 font-medium">{formattedLabel}</div>
      <div className="flex flex-col gap-0.5">
        {payload.map((item, i) => {
          const key = item.dataKey ?? item.name ?? ''
          const conf = config[key]
          return (
            <div key={i} className="flex items-center gap-2">
              <div
                className="size-2.5 rounded-[2px]"
                style={{ background: item.color || conf?.color }}
              />
              <span className="text-muted-foreground">{conf?.label || item.name}:</span>
              <span className="font-medium">
                {typeof item.value === 'number' ? item.value.toLocaleString() : item.value}
              </span>
            </div>
          )
        })}
      </div>
    </div>
  )
}
