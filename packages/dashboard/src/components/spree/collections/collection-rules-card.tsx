import type { CustomFieldDefinition, ResourceTypeDefinition } from '@spree/admin-sdk'
import { COLLECTION_RULE_MATCH_POLICIES, MATCH_POLICIES } from '@spree/core'
import {
  CurrencySelect,
  ResourceCombobox,
  typeLabel,
  useStore,
  useTenantId,
} from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  Checkbox,
  Field,
  FieldError,
  FieldLabel,
  Input,
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
  InputGroupText,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@spree/dashboard-ui'
import { PlusIcon, Trash2Icon } from '@spree/dashboard-ui/icons'
import { useQuery } from '@tanstack/react-query'
import { useState } from 'react'
import { Controller, type UseFormReturn, useFieldArray } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { categoryAutocompleteProps } from '../../../hooks/use-categories'
import { useCollectionRuleTypes } from '../../../hooks/use-collections'
import { customFieldDefinitionAutocompleteProps } from '../../../hooks/use-custom-field-definitions'
import { productTypeAutocompleteProps } from '../../../hooks/use-product-types'
import { sellerAutocompleteProps } from '../../../hooks/use-sellers'
import {
  blankCollectionRule,
  type CollectionFormValues,
  type CollectionRuleFormValues,
} from '../../../schemas/collection'

/** A rule type as `/collection_rules/types` lists it. */
type CollectionRuleType = ResourceTypeDefinition & {
  match_policies?: string[]
  value_required?: boolean
  /** Evaluated in a currency, the store's default when the rule names none. */
  uses_currency?: boolean
}

type MatchPolicy = CollectionRuleFormValues['match_policy']

/** Rule types whose value names a record, and the picker that finds it. */
const RECORD_PICKERS = {
  category: categoryAutocompleteProps,
  product_type: productTypeAutocompleteProps,
  seller: sellerAutocompleteProps,
} as const

/** Product custom fields marked for collection rules; the value input follows the field's type. */
const customFieldDefinitionPicker = customFieldDefinitionAutocompleteProps('product', {
  collection_condition_eq: true,
})

/**
 * Membership card: the rules that pick products automatically. Membership
 * mixes rule-matched products with ones picked by hand in the products card,
 * so a collection with no rules is simply curated by hand.
 *
 * The rules array is a sync setter server-side — what's rendered here is the
 * complete desired state, so removing a row deletes that rule on save.
 */
export function CollectionRulesCard({ form }: { form: UseFormReturn<CollectionFormValues> }) {
  const { t } = useTranslation()
  const { errors } = form.formState

  const rules = useFieldArray({ control: form.control, name: 'rules', keyName: '_key' })

  // Rule kinds come from the server registry, so a plugin-registered rule shows
  // up here without a dashboard change. Labels are localized server-side.
  const { data: ruleTypesResponse } = useCollectionRuleTypes()
  const ruleTypes = (ruleTypesResponse?.data ?? []) as CollectionRuleType[]
  const typeOptions = ruleTypes.map((ruleType) => ({
    value: ruleType.type,
    label: typeLabel('collection_rule', ruleType.type, ruleType.label),
  }))

  // A new row starts on the type's first relation, so the Select always shows
  // a real option.
  const ruleFor = (type: string): CollectionRuleFormValues => {
    const policies = policiesFor(ruleTypes, type)
    return {
      ...blankCollectionRule(),
      type,
      match_policy: policies[0] ?? 'is_equal_to',
      value: type === 'sale' ? 'true' : '',
    }
  }
  const rulesMatchPolicyOptions = MATCH_POLICIES.map((value) => ({
    value,
    label: t(`admin.collections.rules_match_policies.${value}`),
  }))

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.collections.rules.title')}</CardTitle>
        <CardDescription>{t('admin.collections.rules.description')}</CardDescription>
      </CardHeader>
      <CardContent className="flex flex-col gap-6">
        {rules.fields.length > 1 && (
          <Field>
            <FieldLabel htmlFor="collection-rules-match-policy">
              {t('admin.collections.fields.rules_match_policy.label')}
            </FieldLabel>
            <Controller
              control={form.control}
              name="rules_match_policy"
              render={({ field }) => (
                <Select
                  items={rulesMatchPolicyOptions}
                  value={field.value}
                  onValueChange={field.onChange}
                >
                  <SelectTrigger id="collection-rules-match-policy">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {rulesMatchPolicyOptions.map((option) => (
                      <SelectItem key={option.value} value={option.value}>
                        {option.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )}
            />
            <FieldError errors={[errors.rules_match_policy]} />
          </Field>
        )}

        <div className="flex flex-col gap-3">
          {rules.fields.map((ruleField, index) => (
            <RuleRow
              key={ruleField._key}
              form={form}
              index={index}
              ruleTypes={ruleTypes}
              typeOptions={typeOptions}
              onTypeChange={(type) =>
                rules.update(index, { ...ruleFor(type), id: form.getValues(`rules.${index}.id`) })
              }
              onRemove={() => rules.remove(index)}
            />
          ))}

          <Button
            type="button"
            variant="outline"
            size="sm"
            className="self-start"
            onClick={() => rules.append(ruleFor(typeOptions[0]?.value ?? 'tag'))}
          >
            <PlusIcon className="size-4" />
            {t('admin.collections.rules.add')}
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}

function policiesFor(ruleTypes: CollectionRuleType[], type: string): MatchPolicy[] {
  const known: readonly string[] = COLLECTION_RULE_MATCH_POLICIES
  const listed = ruleTypes.find((ruleType) => ruleType.type === type)?.match_policies
  return (listed ?? COLLECTION_RULE_MATCH_POLICIES).filter((policy): policy is MatchPolicy =>
    known.includes(policy),
  )
}

function RuleRow({
  form,
  index,
  ruleTypes,
  typeOptions,
  onTypeChange,
  onRemove,
}: {
  form: UseFormReturn<CollectionFormValues>
  index: number
  ruleTypes: CollectionRuleType[]
  typeOptions: { value: string; label: string }[]
  onTypeChange: (type: string) => void
  onRemove: () => void
}) {
  const { t } = useTranslation()
  const type = form.watch(`rules.${index}.type`)
  const ruleType = ruleTypes.find((entry) => entry.type === type)
  const matchPolicyOptions = policiesFor(ruleTypes, type).map((value) => ({
    value,
    label: t(`admin.collections.rule_match_policies.${value}`),
  }))

  return (
    <div className="flex flex-col gap-3 rounded-lg border border-border-subtle p-3">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-start">
        <Field className="flex-1">
          <FieldLabel className="sr-only">
            {t('admin.collections.fields.rule_type.label')}
          </FieldLabel>
          <Controller
            control={form.control}
            name={`rules.${index}.type`}
            render={({ field }) => (
              <Select
                items={typeOptions}
                value={field.value}
                onValueChange={(next) => {
                  if (next && next !== field.value) onTypeChange(next)
                }}
              >
                <SelectTrigger aria-label={t('admin.collections.fields.rule_type.label')}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {typeOptions.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
          />
        </Field>

        <Field className="flex-1">
          <FieldLabel className="sr-only">
            {t('admin.collections.fields.rule_match_policy.label')}
          </FieldLabel>
          <Controller
            control={form.control}
            name={`rules.${index}.match_policy`}
            render={({ field }) => (
              <Select items={matchPolicyOptions} value={field.value} onValueChange={field.onChange}>
                <SelectTrigger aria-label={t('admin.collections.fields.rule_match_policy.label')}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {matchPolicyOptions.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
          />
        </Field>

        {/* A sale rule's value is always `true`, so it gets no input. */}
        {ruleType?.value_required !== false && type !== 'sale' && (
          <div className="flex-1">
            <RuleValueField form={form} index={index} type={type} />
          </div>
        )}

        <Button
          type="button"
          variant="ghost"
          size="icon"
          aria-label={t('admin.collections.rules.remove')}
          onClick={onRemove}
        >
          <Trash2Icon className="size-4" />
        </Button>
      </div>

      <RuleSettings
        form={form}
        index={index}
        type={type}
        usesCurrency={!!ruleType?.uses_currency}
      />
    </div>
  )
}

/** The value input, shaped by the rule type. */
function RuleValueField({
  form,
  index,
  type,
}: {
  form: UseFormReturn<CollectionFormValues>
  index: number
  type: string
}) {
  const { t } = useTranslation()
  const { defaultCurrency } = useStore()
  const error = form.formState.errors.rules?.[index]?.value
  const inputId = `collection-rule-value-${index}`
  const label = (
    <FieldLabel className="sr-only" htmlFor={inputId}>
      {t('admin.collections.fields.rule_value.label')}
    </FieldLabel>
  )

  if (type in RECORD_PICKERS) {
    const picker = RECORD_PICKERS[type as keyof typeof RECORD_PICKERS](
      `collection-rule-${type}-${index}`,
    )
    return (
      <Field>
        {label}
        <Controller
          control={form.control}
          name={`rules.${index}.value`}
          render={({ field }) => (
            // The pickers differ only in their record type, which the value
            // (a prefixed id) never exposes.
            <ResourceCombobox
              {...(picker as unknown as Parameters<typeof ResourceCombobox>[0])}
              id={inputId}
              value={field.value || null}
              onChange={(next) => field.onChange(next ?? '')}
            />
          )}
        />
        <FieldError errors={[error]} />
      </Field>
    )
  }

  if (type === 'price') {
    const currency = form.watch(`rules.${index}.currency`) || defaultCurrency
    return (
      <Field>
        {label}
        <InputGroup>
          <InputGroupInput
            id={inputId}
            type="number"
            inputMode="decimal"
            step="0.01"
            placeholder="50.00"
            aria-invalid={!!error || undefined}
            {...form.register(`rules.${index}.value`)}
          />
          <InputGroupAddon align="inline-end">
            <InputGroupText>{currency}</InputGroupText>
          </InputGroupAddon>
        </InputGroup>
        <FieldError errors={[error]} />
      </Field>
    )
  }

  if (type === 'custom_field') return <CustomFieldValueField form={form} index={index} />

  return (
    <Field>
      {label}
      <Input
        id={inputId}
        placeholder={t('admin.collections.fields.rule_value.placeholder')}
        aria-invalid={!!error || undefined}
        {...form.register(`rules.${index}.value`)}
      />
      <FieldError errors={[error]} />
    </Field>
  )
}

/** The custom field to compare and the value, typed by the field. */
function CustomFieldValueField({
  form,
  index,
}: {
  form: UseFormReturn<CollectionFormValues>
  index: number
}) {
  const { t } = useTranslation()
  const error = form.formState.errors.rules?.[index]?.value
  const preferences = form.watch(`rules.${index}.preferences`)
  const definitionId = (preferences?.custom_field_definition_id as string | undefined) ?? null
  const picker = customFieldDefinitionPicker(`collection-rule-custom-field-${index}`)
  // The picked record carries the field type. On load the same query the
  // picker hydrates its label from answers it, so this is no extra request.
  const [picked, setPicked] = useState<CustomFieldDefinition | null>(null)
  const tenantId = useTenantId()
  const { data: hydrated } = useQuery({
    queryKey: [picker.queryKey, tenantId, 'hydrate', definitionId],
    queryFn: () => picker.hydrate([definitionId as string]),
    enabled: !!definitionId && picked?.id !== definitionId,
    staleTime: 60_000,
  })
  const definition = picked?.id === definitionId ? picked : hydrated?.data[0]
  const fieldType = definition?.field_type
  const booleanOptions = ['true', 'false'].map((value) => ({
    value,
    label: t(`admin.collections.rules.boolean_${value}`),
  }))

  return (
    <div className="flex flex-col gap-2">
      <Field>
        <FieldLabel className="sr-only">
          {t('admin.collections.rules.custom_field_label')}
        </FieldLabel>
        <ResourceCombobox<CustomFieldDefinition>
          {...picker}
          placeholder={t('admin.collections.rules.custom_field_placeholder')}
          emptyText={t('admin.collections.rules.custom_field_empty')}
          value={definitionId}
          onChange={(next, record) => {
            setPicked(record)
            form.setValue(
              `rules.${index}.preferences`,
              { ...preferences, custom_field_definition_id: next ?? undefined },
              { shouldDirty: true },
            )
          }}
        />
      </Field>
      <Field>
        <FieldLabel className="sr-only" htmlFor={`collection-rule-value-${index}`}>
          {t('admin.collections.fields.rule_value.label')}
        </FieldLabel>
        {fieldType === 'boolean' ? (
          <Controller
            control={form.control}
            name={`rules.${index}.value`}
            render={({ field }) => (
              <Select items={booleanOptions} value={field.value} onValueChange={field.onChange}>
                <SelectTrigger id={`collection-rule-value-${index}`}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {booleanOptions.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
          />
        ) : (
          <Input
            id={`collection-rule-value-${index}`}
            type={fieldType === 'number' ? 'number' : 'text'}
            placeholder={t('admin.collections.fields.rule_value.placeholder')}
            aria-invalid={!!error || undefined}
            {...form.register(`rules.${index}.value`)}
          />
        )}
        <FieldError errors={[error]} />
      </Field>
    </div>
  )
}

/** Per-type settings under the row: subcategories, currency. */
function RuleSettings({
  form,
  index,
  type,
  usesCurrency,
}: {
  form: UseFormReturn<CollectionFormValues>
  index: number
  type: string
  usesCurrency: boolean
}) {
  const { t } = useTranslation()
  const { defaultCurrency } = useStore()

  if (type === 'category') {
    const preferences = form.watch(`rules.${index}.preferences`)
    const checkboxId = `collection-rule-descendants-${index}`
    return (
      <Field orientation="horizontal">
        <Checkbox
          id={checkboxId}
          checked={Boolean(preferences?.include_descendants)}
          onCheckedChange={(checked) =>
            form.setValue(
              `rules.${index}.preferences`,
              { ...preferences, include_descendants: checked === true },
              { shouldDirty: true },
            )
          }
        />
        <FieldLabel htmlFor={checkboxId} className="font-normal">
          {t('admin.collections.rules.include_descendants')}
        </FieldLabel>
      </Field>
    )
  }

  if (usesCurrency) {
    const currencyId = `collection-rule-currency-${index}`
    return (
      <Field orientation="horizontal" className="items-center">
        <FieldLabel htmlFor={currencyId} className="font-normal">
          {t('admin.collections.rules.currency_label')}
        </FieldLabel>
        <Controller
          control={form.control}
          name={`rules.${index}.currency`}
          render={({ field }) => (
            <CurrencySelect
              id={currencyId}
              triggerSize="sm"
              value={field.value ?? ''}
              // The store's default is sent as null, so the rule follows the
              // store if its default currency changes.
              onChange={(currency) =>
                field.onChange(currency === defaultCurrency ? null : currency)
              }
            />
          )}
        />
      </Field>
    )
  }

  return null
}
