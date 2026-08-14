import {
  Alert,
  AlertDescription,
  AlertTitle,
  Field,
  FieldDescription,
  FieldLabel,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@spree/dashboard-ui'
import { TriangleAlertIcon } from 'lucide-react'
import { Controller, type UseFormReturn } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useTaxProviders } from '../../hooks/use-tax-rates'

/** One entry from `GET /tax_providers` — classes registered in code, not rows. */
interface TaxProviderOption {
  id: string
  name: string
  available: boolean
  default: boolean
  unsupported_capabilities?: Array<{ key: string; label: string; description?: string }>
}

/** Any form whose values carry a `tax_provider` string. */
interface TaxProviderFormShape {
  tax_provider?: string
}

/**
 * Picks the tax engine for a market, and — the reason this endpoint exists —
 * shows what the chosen engine cannot do. A merchant selling into US states
 * should be told at configuration time that the built-in engine has no local
 * tax data, rather than discovering it from a tax bill.
 */
export function TaxProviderField<T extends TaxProviderFormShape>({
  form,
}: {
  form: UseFormReturn<T>
}) {
  const { t } = useTranslation()
  const { data } = useTaxProviders()
  const providers = (data?.data ?? []) as unknown as TaxProviderOption[]

  const defaultProvider = providers.find((provider) => provider.default)
  const defaultLabel = defaultProvider
    ? t('admin.tax_providers.use_default_named', { name: defaultProvider.name })
    : t('admin.tax_providers.use_default')

  return (
    <Controller
      // The cast is the standard react-hook-form generic dance: the shape
      // guarantees the key exists, but Path<T> can't see that.
      name={'tax_provider' as never}
      control={form.control}
      render={({ field }) => {
        const selectedId = (field.value as string) || ''
        const selected = providers.find((provider) => provider.id === selectedId)
        // An unselected market runs on the installation default, so that is
        // whose limits apply.
        const effective = selected ?? defaultProvider
        const unsupported = effective?.unsupported_capabilities ?? []

        return (
          <Field>
            <FieldLabel htmlFor="market-tax-provider">
              {t('admin.fields.market.tax_provider.label')}
            </FieldLabel>
            <Select
              value={selectedId || 'default'}
              onValueChange={(value) => field.onChange(value === 'default' ? '' : value)}
            >
              <SelectTrigger id="market-tax-provider">
                <SelectValue>
                  {(value) =>
                    !value || value === 'default'
                      ? defaultLabel
                      : (providers.find((provider) => provider.id === value)?.name ??
                        (value as string))
                  }
                </SelectValue>
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="default">{defaultLabel}</SelectItem>
                {providers.map((provider) => (
                  <SelectItem key={provider.id} value={provider.id} disabled={!provider.available}>
                    {provider.available
                      ? provider.name
                      : t('admin.tax_providers.unavailable_option', { name: provider.name })}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <FieldDescription>{t('admin.fields.market.tax_provider.help')}</FieldDescription>

            {unsupported.length > 0 && (
              <Alert variant="warning" className="mt-1">
                <TriangleAlertIcon />
                <AlertTitle>
                  {t('admin.tax_providers.limitations_title', { name: effective?.name ?? '' })}
                </AlertTitle>
                <AlertDescription>
                  <ul className="flex list-disc flex-col gap-1 pl-4">
                    {unsupported.map((capability) => (
                      <li key={capability.key}>
                        {capability.label}
                        {capability.description ? ` — ${capability.description}` : ''}
                      </li>
                    ))}
                  </ul>
                </AlertDescription>
              </Alert>
            )}
          </Field>
        )
      }}
    />
  )
}
