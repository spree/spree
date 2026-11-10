import type { Market } from '@spree/admin-sdk'
import { intlDisplayName } from '@spree/core'
import { defineTable, LocaleLabel } from '@spree/dashboard-core'
import {
  ActiveBadge,
  Button,
  CountryFlag,
  CurrencyLabel,
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
  Popover,
  PopoverContent,
  PopoverTrigger,
  ResourceNameCell,
} from '@spree/dashboard-ui'
import { ChevronDownIcon, GlobeIcon, SearchIcon } from '@spree/dashboard-ui/icons'
import i18n from 'i18next'
import { useState } from 'react'

const countryName = (code: string) => intlDisplayName('region', i18n.language, code) ?? code

// One country reads as its flag and name; several collapse to a count that
// opens the full list. The list is searchable once it is too long to scan.
const SEARCHABLE_FROM = 8

function MarketRegions({ codes }: { codes: string[] }) {
  const [query, setQuery] = useState('')

  if (codes.length === 0) return <span className="text-muted-foreground">—</span>
  if (codes.length === 1) {
    return (
      <span className="inline-flex items-center gap-2">
        <CountryFlag iso={codes[0]} />
        {countryName(codes[0])}
      </span>
    )
  }

  const countries = codes
    .map((code) => ({ code, name: countryName(code) }))
    .sort((a, b) => a.name.localeCompare(b.name, i18n.language))
  const needle = query.trim().toLocaleLowerCase()
  const shown = needle
    ? countries.filter(
        (c) => c.name.toLocaleLowerCase().includes(needle) || c.code.toLowerCase() === needle,
      )
    : countries

  return (
    <Popover onOpenChange={(open) => !open && setQuery('')}>
      <PopoverTrigger asChild>
        <Button variant="ghost" size="sm" className="-mx-2 gap-2 font-normal">
          <GlobeIcon className="size-4 text-muted-foreground" />
          {i18n.t('admin.markets.regions_count', { count: codes.length })}
          <ChevronDownIcon className="size-3.5 text-muted-foreground" />
        </Button>
      </PopoverTrigger>
      <PopoverContent align="start" className="w-64 cursor-default overflow-hidden p-0">
        {codes.length >= SEARCHABLE_FROM && (
          <div className="border-b p-2">
            <InputGroup>
              <InputGroupAddon>
                <SearchIcon />
              </InputGroupAddon>
              <InputGroupInput
                autoFocus
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder={i18n.t('admin.markets.search_regions')}
                aria-label={i18n.t('admin.markets.search_regions')}
              />
            </InputGroup>
          </div>
        )}
        <ul className="max-h-72 overflow-y-auto p-1">
          {shown.map((c) => (
            <li key={c.code} className="flex items-center gap-3 rounded-md px-2 py-1.5 text-base">
              <CountryFlag iso={c.code} />
              {c.name}
            </li>
          ))}
          {shown.length === 0 && (
            <li className="px-2 py-3 text-center text-base text-muted-foreground">
              {i18n.t('admin.common.no_results')}
            </li>
          )}
        </ul>
      </PopoverContent>
    </Popover>
  )
}

defineTable<Market>('markets', {
  title: i18n.t('admin.settings_nav.items.markets'),
  docsPath: 'settings/markets',
  description: i18n.t('admin.table_descriptions.markets'),
  searchParam: 'search',
  searchPlaceholder: i18n.t('admin.markets.search_placeholder'),
  defaultSort: { field: 'position', direction: 'asc' },
  emptyIcon: <GlobeIcon className="size-8 text-muted-foreground" />,
  emptyMessage: i18n.t('admin.markets.empty'),
  columns: [
    {
      key: 'name',
      label: i18n.t('admin.fields.name.label'),
      sortable: true,
      default: true,
      render: (market) => (
        <ResourceNameCell id={market.id} dataAttr="data-market-id" name={market.name} />
      ),
    },
    {
      key: 'currency',
      label: i18n.t('admin.fields.currency.label'),
      sortable: true,
      default: true,
      render: (market) => <CurrencyLabel code={market.currency} />,
    },
    {
      key: 'country_codes',
      label: i18n.t('admin.markets.columns.regions'),
      default: true,
      render: (market) => <MarketRegions codes={market.country_codes} />,
    },
    {
      key: 'default_locale',
      label: i18n.t('admin.markets.columns.locale'),
      sortable: true,
      default: true,
      render: (market) => <LocaleLabel code={market.default_locale} />,
    },
    {
      key: 'tax_inclusive',
      label: i18n.t('admin.fields.tax.label'),
      default: true,
      render: (market) => (
        <ActiveBadge
          active={market.tax_inclusive}
          activeLabel={i18n.t('admin.markets.tax_inclusive')}
          inactiveLabel={i18n.t('admin.markets.tax_exclusive')}
        />
      ),
    },
    {
      key: 'default',
      label: i18n.t('admin.markets.columns.default'),
      default: true,
      render: (market) => (
        <ActiveBadge
          active={market.default}
          activeLabel={i18n.t('admin.markets.columns.default')}
          dashWhenInactive
        />
      ),
    },
  ],
})
