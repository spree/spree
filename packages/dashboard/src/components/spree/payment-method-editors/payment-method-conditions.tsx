import type { PaymentMethodRule } from '@spree/admin-sdk'
import { formatMoney } from '@spree/core'
import type { adminClient } from '@spree/dashboard-core'
import {
  currencyParts,
  defaultPreferences,
  filterPreferenceSchema,
  PreferencesForm,
  ResourceMultiAutocomplete,
  typeDescription,
  typeLabel,
  useStore,
} from '@spree/dashboard-core'
import {
  Badge,
  Button,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  Field,
  FieldLabel,
  FormSection,
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
  InputGroupText,
  Item,
  ItemActions,
  ItemContent,
  ItemDescription,
  ItemTitle,
} from '@spree/dashboard-ui'
import { PlusIcon, Trash2Icon } from 'lucide-react'
import { Controller, type UseFormReturn, useFieldArray } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import {
  PAYMENT_METHOD_RULE_PICKERS as PICKERS,
  usePaymentMethodRuleRecordNames,
  usePaymentMethodRuleTypes,
} from '../../../hooks/use-payment-methods'
import type { PaymentMethodFormValues } from './types'

type PaymentMethodRuleType = Awaited<
  ReturnType<typeof adminClient.paymentMethods.ruleTypes>
>['data'][number]

/**
 * The conditions that decide whether a payment method is offered at
 * storefront checkout. Held in form state and saved with the method.
 */
export function PaymentMethodConditions({
  form,
}: {
  form: UseFormReturn<PaymentMethodFormValues>
}) {
  const { t } = useTranslation()
  const { data: ruleTypes } = usePaymentMethodRuleTypes()
  const rulesArray = useFieldArray({ control: form.control, name: 'rules', keyName: '_key' })

  const existingTypes = new Set(rulesArray.fields.map((rule) => rule.type))
  const availableTypes = (ruleTypes?.data ?? []).filter((type) => !existingTypes.has(type.type))

  return (
    <FormSection
      title={t('admin.payment_methods.conditions.title')}
      description={t('admin.payment_methods.conditions.description')}
      action={
        availableTypes.length > 0 && (
          <DropdownMenu>
            <DropdownMenuTrigger
              render={
                <Button type="button" variant="outline" size="sm">
                  <PlusIcon className="size-4" />
                  {t('admin.payment_methods.conditions.add')}
                </Button>
              }
            />
            <DropdownMenuContent align="end">
              {availableTypes.map((type) => (
                <DropdownMenuItem
                  key={type.type}
                  onClick={() =>
                    rulesArray.append({
                      type: type.type,
                      preferences: defaultPreferences(type.schema),
                    })
                  }
                >
                  {typeLabel('payment_method_rule', type.type, type.label)}
                </DropdownMenuItem>
              ))}
            </DropdownMenuContent>
          </DropdownMenu>
        )
      }
    >
      <div className="flex flex-col gap-3">
        {rulesArray.fields.length === 0 && (
          <p className="text-muted-foreground text-sm">
            {t('admin.payment_methods.conditions.empty')}
          </p>
        )}

        {rulesArray.fields.map((field, index) => (
          <ConditionRow
            key={field._key}
            form={form}
            index={index}
            ruleType={(ruleTypes?.data ?? []).find((candidate) => candidate.type === field.type)}
            fallbackLabel={field.type}
            onRemove={() => rulesArray.remove(index)}
          />
        ))}
      </div>
    </FormSection>
  )
}

function ConditionRow({
  form,
  index,
  ruleType,
  fallbackLabel,
  onRemove,
}: {
  form: UseFormReturn<PaymentMethodFormValues>
  index: number
  ruleType?: PaymentMethodRuleType
  fallbackLabel: string
  onRemove: () => void
}) {
  const { t } = useTranslation()
  const schema = ruleType?.schema
  const properties = Object.entries(schema?.properties ?? {})
  // An id list the schema marks with a record prefix gets that record's picker.
  const idList = properties.find(
    ([, property]) => PICKERS[property.items?.['x-spree-prefix'] ?? ''],
  )
  // Per-currency amounts (`{ "USD": "5000" }`) get one input per currency.
  const currencyAmountKeys = properties
    .filter(([, property]) => property.propertyNames?.format === 'currency')
    .map(([key]) => key)
  const remainingSchema =
    schema &&
    filterPreferenceSchema(
      schema,
      (key) => key !== idList?.[0] && !currencyAmountKeys.includes(key),
    )
  const label = ruleType
    ? typeLabel('payment_method_rule', ruleType.type, ruleType.label)
    : fallbackLabel
  const description = ruleType
    ? typeDescription('payment_method_rule', ruleType.type, ruleType.description)
    : ''

  return (
    <Item variant="outline" data-condition={label}>
      <ItemContent>
        <ItemTitle>{label}</ItemTitle>
        {description && <ItemDescription>{description}</ItemDescription>}
      </ItemContent>
      <ItemActions>
        <Button
          type="button"
          variant="destructive-ghost"
          size="icon-sm"
          onClick={onRemove}
          aria-label={t('admin.payment_methods.conditions.remove', { name: label })}
        >
          <Trash2Icon className="size-4" />
        </Button>
      </ItemActions>

      <Controller
        control={form.control}
        name={`rules.${index}.preferences`}
        render={({ field }) => {
          const values = field.value ?? {}
          const prefix = idList?.[1].items?.['x-spree-prefix']
          const picker = prefix ? PICKERS[prefix] : undefined
          return (
            <div className="flex basis-full flex-col gap-3">
              {idList && picker && (
                <ResourceMultiAutocomplete
                  {...picker(`payment-method-rule-${ruleType?.type}`)}
                  value={(values[idList[0]] ?? []) as string[]}
                  onChange={(ids: string[]) => field.onChange({ ...values, [idList[0]]: ids })}
                />
              )}
              {currencyAmountKeys.length > 0 && (
                <CurrencyBounds
                  keys={currencyAmountKeys}
                  values={values}
                  onChange={field.onChange}
                />
              )}
              {remainingSchema && Object.keys(remainingSchema.properties).length > 0 && (
                <PreferencesForm
                  schema={remainingSchema}
                  values={values}
                  onChange={field.onChange}
                />
              )}
            </div>
          )
        }}
      />
    </Item>
  )
}

/**
 * One amount per store currency for each per-currency preference (minimum and
 * maximum order total). A blank amount means that currency is unrestricted on
 * that side.
 */
function CurrencyBounds({
  keys,
  values,
  onChange,
}: {
  keys: string[]
  values: Record<string, unknown>
  onChange: (next: Record<string, unknown>) => void
}) {
  const { t, i18n } = useTranslation()
  const { currencies, defaultCurrency } = useStore()
  const codes = [defaultCurrency, ...currencies.filter((code) => code !== defaultCurrency)]

  return (
    <div className="flex flex-col gap-3">
      {keys.map((key) => {
        const amounts = (values[key] ?? {}) as Record<string, string>
        return (
          <Field key={key}>
            <FieldLabel>{t(`admin.payment_methods.conditions.fields.${key}`)}</FieldLabel>
            <div className="grid gap-2 sm:grid-cols-2">
              {codes.map((code) => (
                <InputGroup key={code}>
                  <InputGroupAddon>
                    <InputGroupText>{currencyParts(code, i18n.language).symbol}</InputGroupText>
                  </InputGroupAddon>
                  <InputGroupInput
                    type="number"
                    inputMode="decimal"
                    min="0"
                    step="any"
                    aria-label={`${t(`admin.payment_methods.conditions.fields.${key}`)} (${code})`}
                    value={amounts[code] ?? ''}
                    onChange={(event) => {
                      const { [code]: _removed, ...rest } = amounts
                      const next =
                        event.target.value === '' ? rest : { ...rest, [code]: event.target.value }
                      onChange({ ...values, [key]: next })
                    }}
                  />
                  <InputGroupAddon align="inline-end">
                    <InputGroupText>{code}</InputGroupText>
                  </InputGroupAddon>
                </InputGroup>
              ))}
            </div>
          </Field>
        )
      })}
    </div>
  )
}

/**
 * A payment method's conditions as one badge each, such as "Market: Europe",
 * so two accounts of one provider can be told apart on the payments list.
 */
export function PaymentMethodConditionsSummary({ rules }: { rules: PaymentMethodRule[] }) {
  const { data: ruleTypes } = usePaymentMethodRuleTypes()
  if (rules.length === 0) return null

  return (
    <div className="flex flex-wrap gap-1.5">
      {rules.map((rule) => (
        <ConditionSummary
          key={rule.id}
          rule={rule}
          ruleType={(ruleTypes?.data ?? []).find((candidate) => candidate.type === rule.type)}
        />
      ))}
    </div>
  )
}

function ConditionSummary({
  rule,
  ruleType,
}: {
  rule: PaymentMethodRule
  ruleType?: PaymentMethodRuleType
}) {
  const { t, i18n } = useTranslation()
  const preferences = rule.preferences ?? {}
  const properties = Object.entries(ruleType?.schema?.properties ?? {})
  const idList = properties.find(
    ([, property]) => PICKERS[property.items?.['x-spree-prefix'] ?? ''],
  )
  const { data: names = [] } = usePaymentMethodRuleRecordNames(
    idList?.[1].items?.['x-spree-prefix'],
    idList ? ((preferences[idList[0]] ?? []) as string[]) : [],
  )
  const bounds = properties
    .filter(([, property]) => property.propertyNames?.format === 'currency')
    .flatMap(([key]) =>
      Object.entries((preferences[key] ?? {}) as Record<string, string>).map(([code, amount]) =>
        t(`admin.payment_methods.conditions.summary.${key}`, {
          amount: formatMoney(amount, code, i18n.language),
        }),
      ),
    )
  const label = ruleType
    ? typeLabel('payment_method_rule', ruleType.type, ruleType.label)
    : rule.type
  const details = [...names, ...bounds]
  const text = details.length > 0 ? `${label}: ${details.join(', ')}` : label

  return (
    <Badge variant="outline" className="max-w-full" title={text}>
      <span className="truncate">{text}</span>
    </Badge>
  )
}
