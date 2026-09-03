import type { ReportingGrain, ReportingSchema, ReportingSchemaDimension } from '@spree/admin-sdk'
import {
  CountryMultiCombobox,
  MarketMultiCombobox,
  ResourceMultiAutocomplete,
  resolveDatePreset,
  useStore,
} from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Checkbox,
  cn,
  type DateRange,
  DateRangePicker,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  Field,
  FieldLabel,
  FieldLegend,
  FieldSet,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@spree/dashboard-ui'
import { PlusIcon, XIcon } from '@spree/dashboard-ui/icons'
import { format, parseISO } from 'date-fns'
import { useTranslation } from 'react-i18next'
import { categoryAutocompleteProps } from '../../../hooks/use-categories'
import { channelAutocompleteProps, useChannels } from '../../../hooks/use-channels'
import { customerAutocompleteProps } from '../../../hooks/use-customers'
import { useAllMarkets } from '../../../hooks/use-markets'
import { productAutocompleteProps } from '../../../hooks/use-products'
import { findDimension, isTimeDimension, type ReportDraft, type ReportFilter } from './report-draft'

const NONE = '__none__'
const CUSTOM_RANGE = '__custom__'

interface ReportBuilderProps {
  draft: ReportDraft
  onChange: (draft: ReportDraft) => void
  schema: ReportingSchema
}

/**
 * Sidebar editor for a report draft, driven entirely by the reporting schema:
 * which metrics exist, which dimensions they can be grouped or filtered by,
 * which time presets the server knows. Nothing in here names a metric.
 */
export function ReportBuilder({ draft, onChange, schema }: ReportBuilderProps) {
  const { t } = useTranslation()
  const { timezone } = useStore()
  const dimension = findDimension(schema, draft.dimension)
  const timeDimension = isTimeDimension(dimension)

  const update = (patch: Partial<ReportDraft>) => onChange({ ...draft, ...patch })

  const groupableDimensions = schema.dimensions.filter((d) =>
    draft.metrics.every((metric) => d.compatible_metrics.includes(metric)),
  )
  const dimensionOptions = [
    { value: NONE, label: t('admin.reports.builder.none') },
    ...groupableDimensions.map((d) => ({ value: d.name, label: d.label })),
  ]

  const grainOptions = (dimension?.grains ?? []).map((grain) => ({
    value: grain,
    label: t(`admin.reports.grains.${grain}`),
  }))

  // Presets come from the schema (named + common relative ranges); whatever a
  // saved report carries stays selectable even if it is not among them.
  const presetValue = 'preset' in draft.timeRange ? draft.timeRange.preset : CUSTOM_RANGE
  const presetOptions = [
    ...schema.time_range.presets.map((preset) => ({ value: preset.name, label: preset.label })),
    { value: CUSTOM_RANGE, label: t('admin.reports.builder.custom_range') },
  ]
  if (!presetOptions.some((option) => option.value === presetValue)) {
    presetOptions.unshift({ value: presetValue, label: presetValue.replace(/_/g, ' ') })
  }
  // A custom range travels as bare dates: the server widens them to the
  // store's whole day on each edge, so the last day is never cut off at
  // the browser's midnight and no browser timezone leaks into the query.
  const defaultRange = resolveDatePreset('last_30_days', timezone)
  const customRange: DateRange =
    'since' in draft.timeRange
      ? { from: parseISO(draft.timeRange.since), to: parseISO(draft.timeRange.until) }
      : { from: parseISO(defaultRange.from as string), to: parseISO(defaultRange.to as string) }
  const dateRangeValue = (range: DateRange) => ({
    since: format(range.from, 'yyyy-MM-dd'),
    until: format(range.to, 'yyyy-MM-dd'),
  })

  // Same compatibility rule as Group by: an order-level metric cannot be
  // filtered by a line-item dimension, and the compiler would refuse it.
  const filterableDimensions = schema.dimensions.filter(
    (d) =>
      d.type !== 'time' &&
      draft.metrics.every((metric) => d.compatible_metrics.includes(metric)) &&
      !draft.filters.some((filter) => filter.dimension === d.name),
  )

  const metricOptions = draft.metrics.map((name) => ({
    value: name,
    label: schema.metrics.find((metric) => metric.name === name)?.label ?? name,
  }))
  const directionOptions = [
    { value: 'desc', label: t('admin.reports.builder.sort_desc') },
    { value: 'asc', label: t('admin.reports.builder.sort_asc') },
  ]

  function toggleMetric(name: string, checked: boolean) {
    const metrics = checked
      ? [...draft.metrics, name]
      : draft.metrics.filter((metric) => metric !== name)
    update({ metrics })
  }

  function setDimension(value: string) {
    const next = value === NONE ? null : value
    const definition = findDimension(schema, next)
    update({
      dimension: next,
      grain: definition?.grains?.includes(draft.grain)
        ? draft.grain
        : (definition?.grains?.[0] ?? 'day'),
    })
  }

  function setPreset(value: string) {
    if (value === CUSTOM_RANGE) {
      update({ timeRange: dateRangeValue(customRange) })
    } else {
      update({ timeRange: { preset: value } })
    }
  }

  function addFilter(name: string) {
    update({ filters: [...draft.filters, { dimension: name, values: [] }] })
  }

  function setFilter(index: number, filter: ReportFilter) {
    update({ filters: draft.filters.map((current, i) => (i === index ? filter : current)) })
  }

  function removeFilter(index: number) {
    update({ filters: draft.filters.filter((_, i) => i !== index) })
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.reports.builder.title')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-6">
        <FieldSet className="flex flex-col gap-2">
          <FieldLegend variant="label">{t('admin.reports.builder.metrics')}</FieldLegend>
          {schema.metrics.map((metric) => {
            const id = `metric-${metric.name}`
            // Greyed out when the chosen breakdown or any active filter cannot
            // be combined with this metric.
            const incompatible = [
              dimension,
              ...draft.filters.map((f) => findDimension(schema, f.dimension)),
            ].some((d) => d && !d.compatible_metrics.includes(metric.name))
            return (
              <Field key={metric.name} orientation="horizontal">
                <Checkbox
                  id={id}
                  checked={draft.metrics.includes(metric.name)}
                  disabled={incompatible}
                  onCheckedChange={(checked) => toggleMetric(metric.name, checked)}
                />
                <FieldLabel
                  htmlFor={id}
                  className={cn('font-normal', incompatible && 'text-muted-foreground')}
                >
                  {metric.label}
                </FieldLabel>
              </Field>
            )
          })}
          {draft.metrics.length === 0 && (
            <p className="text-xs text-destructive">{t('admin.reports.builder.no_metrics')}</p>
          )}
        </FieldSet>

        <Field>
          <FieldLabel>{t('admin.reports.builder.group_by')}</FieldLabel>
          <OptionSelect
            items={dimensionOptions}
            value={draft.dimension ?? NONE}
            onValueChange={(value) => setDimension(value as string)}
            label={t('admin.reports.builder.group_by')}
          />
        </Field>

        {timeDimension && grainOptions.length > 0 && (
          <Field>
            <FieldLabel>{t('admin.reports.builder.grain')}</FieldLabel>
            <OptionSelect
              items={grainOptions}
              value={draft.grain}
              onValueChange={(value) => update({ grain: value as ReportingGrain })}
              label={t('admin.reports.builder.grain')}
            />
          </Field>
        )}

        <Field>
          <FieldLabel>{t('admin.reports.builder.time_range')}</FieldLabel>
          <OptionSelect
            items={presetOptions}
            value={presetValue}
            onValueChange={(value) => setPreset(value as string)}
            label={t('admin.reports.builder.time_range')}
          />
          {presetValue === CUSTOM_RANGE && (
            <DateRangePicker
              value={customRange}
              onChange={(range) => update({ timeRange: dateRangeValue(range) })}
            />
          )}
        </Field>

        <Field orientation="horizontal">
          <Checkbox
            id="report-compare"
            checked={draft.compare}
            onCheckedChange={(checked) => update({ compare: checked })}
          />
          <FieldLabel htmlFor="report-compare" className="font-normal">
            {t('admin.reports.builder.compare')}
          </FieldLabel>
        </Field>

        <FieldSet className="flex flex-col gap-3">
          <FieldLegend variant="label" className="mb-0">
            {t('admin.reports.builder.filters')}
          </FieldLegend>
          {draft.filters.map((filter, index) => {
            const definition = findDimension(schema, filter.dimension)
            return (
              <div key={filter.dimension} className="flex flex-col gap-1.5 rounded-md border p-3">
                <div className="flex items-center justify-between gap-2">
                  <span className="text-sm font-medium">
                    {definition?.label ?? filter.dimension}
                  </span>
                  {
                    <Button
                      type="button"
                      variant="ghost"
                      size="icon-sm"
                      aria-label={t('admin.reports.builder.remove_filter')}
                      onClick={() => removeFilter(index)}
                    >
                      <XIcon className="size-4" />
                    </Button>
                  }
                </div>
                <FilterValues
                  dimension={definition}
                  values={filter.values}
                  onChange={(values) => setFilter(index, { ...filter, values })}
                />
              </div>
            )
          })}
          {filterableDimensions.length > 0 && (
            <DropdownMenu>
              <DropdownMenuTrigger
                render={
                  <Button variant="outline" size="sm" className="self-start">
                    <PlusIcon className="size-4" />
                    {t('admin.reports.builder.add_filter')}
                  </Button>
                }
              />
              <DropdownMenuContent align="start">
                {filterableDimensions.map((d) => (
                  <DropdownMenuItem key={d.name} onClick={() => addFilter(d.name)}>
                    {d.label}
                  </DropdownMenuItem>
                ))}
              </DropdownMenuContent>
            </DropdownMenu>
          )}
        </FieldSet>

        {draft.dimension && !timeDimension && (
          <div className="grid grid-cols-2 gap-3">
            <Field className="col-span-2">
              <FieldLabel>{t('admin.reports.builder.sort')}</FieldLabel>
              <OptionSelect
                items={metricOptions}
                value={
                  draft.sortMetric && draft.metrics.includes(draft.sortMetric)
                    ? draft.sortMetric
                    : (draft.metrics[0] ?? null)
                }
                onValueChange={(value) => update({ sortMetric: value as string })}
                label={t('admin.reports.builder.sort')}
                disabled={metricOptions.length === 0}
              />
            </Field>
            <Field>
              <FieldLabel>{t('admin.reports.builder.direction')}</FieldLabel>
              <OptionSelect
                items={directionOptions}
                value={draft.sortDirection}
                onValueChange={(value) => update({ sortDirection: value as 'asc' | 'desc' })}
                label={t('admin.reports.builder.direction')}
              />
            </Field>
            <Field>
              <FieldLabel htmlFor="report-limit">{t('admin.reports.builder.limit')}</FieldLabel>
              <Input
                id="report-limit"
                type="number"
                min={1}
                max={schema.limits.max}
                value={draft.limit}
                onChange={(event) => {
                  const next = Number.parseInt(event.target.value, 10)
                  if (Number.isFinite(next))
                    update({ limit: Math.min(Math.max(next, 1), schema.limits.max) })
                }}
              />
            </Field>
          </div>
        )}
      </CardContent>
    </Card>
  )
}

/** Value picker for one filter, chosen by how the dimension is keyed. */
function FilterValues({
  dimension,
  values,
  onChange,
}: {
  dimension: ReportingSchemaDimension | undefined
  values: string[]
  onChange: (values: string[]) => void
}) {
  const { t } = useTranslation()

  if (!dimension) return null

  if (dimension.values?.length) {
    return (
      <CheckboxList
        idPrefix={`filter-${dimension.name}`}
        options={dimension.values.map((value) => ({ value: value.name, label: value.label }))}
        values={values}
        onChange={onChange}
      />
    )
  }

  // Lookup-backed filters pick records through the same autocompletes the
  // rest of the dashboard uses; a lookup without a picker falls back to ids.
  const key = `report-filter-${dimension.name}`
  switch (dimension.lookup) {
    case 'channel':
      return <ChannelFilterValues values={values} onChange={onChange} />
    case 'category':
      return (
        <ResourceMultiAutocomplete
          {...categoryAutocompleteProps(key)}
          value={values}
          onChange={onChange}
        />
      )
    case 'product':
      return (
        <ResourceMultiAutocomplete
          {...productAutocompleteProps(key)}
          value={values}
          onChange={onChange}
        />
      )
    case 'customer':
      return (
        <ResourceMultiAutocomplete
          {...customerAutocompleteProps(key)}
          value={values}
          onChange={onChange}
        />
      )
    case 'market':
      return <MarketFilterValues values={values} onChange={onChange} />
    case 'country':
      return <CountryMultiCombobox value={values} onValueChange={onChange} />
    default:
      return (
        <Input
          value={values.join(', ')}
          placeholder={t('admin.reports.builder.ids_placeholder')}
          onChange={(event) =>
            onChange(
              event.target.value
                .split(',')
                .map((v) => v.trim())
                .filter(Boolean),
            )
          }
        />
      )
  }
}

function CheckboxList({
  idPrefix,
  options,
  values,
  onChange,
}: {
  idPrefix: string
  options: Array<{ value: string; label: string }>
  values: string[]
  onChange: (values: string[]) => void
}) {
  return (
    <div className="flex flex-col gap-1.5">
      {options.map((option) => {
        const id = `${idPrefix}-${option.value}`
        return (
          <Field key={option.value} orientation="horizontal">
            <Checkbox
              id={id}
              checked={values.includes(option.value)}
              onCheckedChange={(checked) =>
                onChange(
                  checked ? [...values, option.value] : values.filter((v) => v !== option.value),
                )
              }
            />
            <FieldLabel htmlFor={id} className="font-normal">
              {option.label}
            </FieldLabel>
          </Field>
        )
      })}
    </div>
  )
}

/** Markets are a short store-level list, fetched only when a market filter is on screen. */
function MarketFilterValues({
  values,
  onChange,
}: {
  values: string[]
  onChange: (values: string[]) => void
}) {
  const { markets } = useAllMarkets()
  return <MarketMultiCombobox markets={markets} value={values} onValueChange={onChange} />
}

function OptionSelect({
  items,
  value,
  onValueChange,
  label,
  disabled,
}: {
  items: Array<{ value: string; label: string }>
  value: string | null
  onValueChange: (value: string) => void
  label: string
  disabled?: boolean
}) {
  return (
    <Select
      items={items}
      value={value}
      onValueChange={(next) => onValueChange(next as string)}
      disabled={disabled}
    >
      <SelectTrigger aria-label={label}>
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        {items.map((option) => (
          <SelectItem key={option.value} value={option.value}>
            {option.label}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  )
}

/**
 * Channels are a short store-level list, so the picker opens with every one of
 * them rather than waiting for the merchant to type a search that matches.
 */
function ChannelFilterValues({
  values,
  onChange,
}: {
  values: string[]
  onChange: (values: string[]) => void
}) {
  const { data } = useChannels()

  return (
    <ResourceMultiAutocomplete
      {...channelAutocompleteProps('report-filter-channel')}
      initialItems={data?.data}
      value={values}
      onChange={onChange}
    />
  )
}
