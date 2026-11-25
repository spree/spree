import { Subject, usePermissions } from '@spree/dashboard-core'
import {
  Field,
  FieldError,
  FieldLabel,
  Input,
  ResourceCombobox,
  Skeleton,
  useDebouncedValue,
} from '@spree/dashboard-ui'
import { useState } from 'react'
import { Controller, type UseFormReturn } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useTaxCodeSearch, useTaxProviders } from '../../../hooks/use-tax-rates'
import type { TaxCategoryFormValues } from '../../../schemas/tax-category'
import { useMarketTaxProviders } from './market-tax-providers'

const SEARCH_DEBOUNCE_MS = 250

type TaxCodeChoice = { id: string; description: string; typed?: boolean }

/**
 * A tax category's code. Where an engine a market taxes with offers a search
 * of its own codes (Avalara), the field searches them as the merchant types;
 * a typed code is still accepted. Otherwise it is plain text.
 */
export function TaxCodeField({ form }: { form: UseFormReturn<TaxCategoryFormValues> }) {
  const { t } = useTranslation()
  const { errors } = form.formState
  const { data } = useTaxProviders()
  const { permissions } = usePermissions()
  const { groups: marketProviders, isLoading } = useMarketTaxProviders()
  // Only engines a market taxes with, the rule the exemption reason form uses.
  // Staff who cannot see markets fall back to every engine the store has set up.
  const usedProviderIds = permissions.can('read', Subject.Market)
    ? new Set(marketProviders.map((group) => group.providerId))
    : null
  const searchable = (data?.data ?? [])
    .filter((provider) => provider.available && provider.tax_code_lookup)
    .filter((provider) => !usedProviderIds || usedProviderIds.has(provider.id))
    .map((provider) => provider.id)

  return (
    <Field>
      <FieldLabel htmlFor="tax_code">{t('admin.fields.tax_category.tax_code.label')}</FieldLabel>
      {/* Which control fits is only known once the engines and markets load. */}
      {isLoading ? (
        <Skeleton className="h-9 w-full" />
      ) : searchable.length ? (
        <Controller
          control={form.control}
          name="tax_code"
          render={({ field }) => (
            <TaxCodeSearch
              providerIds={searchable}
              value={field.value ?? ''}
              onChange={field.onChange}
            />
          )}
        />
      ) : (
        <Input
          id="tax_code"
          placeholder={t('admin.fields.tax_category.tax_code.placeholder')}
          aria-invalid={!!errors.tax_code || undefined}
          {...form.register('tax_code')}
        />
      )}
      <FieldError errors={[errors.tax_code]} />
    </Field>
  )
}

function TaxCodeSearch({
  providerIds,
  value,
  onChange,
}: {
  providerIds: string[]
  value: string
  onChange: (code: string) => void
}) {
  const { t } = useTranslation()
  const [query, setQuery] = useState('')
  const debounced = useDebouncedValue(query, SEARCH_DEBOUNCE_MS).trim()
  const { data: results = [] } = useTaxCodeSearch(providerIds, debounced)
  const typed = query.trim()

  // The typed text and the saved code stay pickable beside the results, so a
  // code the engine does not list can still be entered and kept. The typed
  // text comes first, where it is the obvious choice; a result for the same
  // code is inserted later and keeps the engine's description. One entry per
  // code, so no engine wins by being asked first.
  const items = [
    ...new Map<string, TaxCodeChoice>(
      [
        ...(typed
          ? [{ id: typed, description: t('admin.fields.tax_category.tax_code.typed'), typed: true }]
          : []),
        ...(value ? [{ id: value, description: '' }] : []),
        ...results.map((code): TaxCodeChoice => ({ id: code.code, description: code.description })),
      ].map((option) => [option.id, option]),
    ).values(),
  ]

  return (
    <ResourceCombobox<TaxCodeChoice>
      id="tax_code"
      value={value || null}
      items={items}
      onInputChange={setQuery}
      onChange={(code) => onChange(code ?? '')}
      getOptionLabel={(option) => option.id}
      renderOption={(option) => (
        <span className="flex min-w-0 flex-col">
          <code className="text-sm">{option.id}</code>
          {option.description && (
            <span
              className={
                option.typed
                  ? 'text-muted-foreground text-xs italic'
                  : 'text-muted-foreground text-xs'
              }
            >
              {option.description}
            </span>
          )}
        </span>
      )}
      placeholder={t('admin.fields.tax_category.tax_code.search_placeholder')}
      emptyText={t('admin.fields.tax_category.tax_code.empty')}
    />
  )
}
