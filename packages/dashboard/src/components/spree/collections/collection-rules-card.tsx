import { COLLECTION_RULE_MATCH_POLICIES, MATCH_POLICIES } from '@spree/core'
import { TagCombobox, typeLabel } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
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
  Switch,
} from '@spree/dashboard-ui'
import { PlusIcon, Trash2Icon } from '@spree/dashboard-ui/icons'
import { Controller, type UseFormReturn, useFieldArray } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useCollectionRuleTypes } from '../../../hooks/use-collections'

import { blankCollectionRule, type CollectionFormValues } from '../../../schemas/collection'

/**
 * Membership card: the manual/automatic switch plus, for automatic
 * collections, the rule set that materializes the members.
 *
 * The rules array is a sync setter server-side — what's rendered here is the
 * complete desired state, so removing a row deletes that rule on save.
 */
export function CollectionRulesCard({ form }: { form: UseFormReturn<CollectionFormValues> }) {
  const { t } = useTranslation()
  const { errors } = form.formState
  const automatic = form.watch('automatic')

  const rules = useFieldArray({ control: form.control, name: 'rules' })

  // Rule kinds come from the server registry, so a plugin-registered rule shows
  // up here without a dashboard change. Labels are localized server-side.
  const { data: ruleTypes } = useCollectionRuleTypes()
  const typeOptions = (ruleTypes?.data ?? []).map((ruleType) => ({
    value: ruleType.type,
    label: typeLabel('collection_rule', ruleType.type, ruleType.label),
  }))

  // Seed a new row from the registry so the Select always shows a real option,
  // even on a deployment that doesn't register the schema's default kind.
  const newRule = () => {
    const type = typeOptions[0]?.value
    return type ? { ...blankCollectionRule(), type, ...ruleSeed(type) } : blankCollectionRule()
  }
  const matchPolicyOptions = COLLECTION_RULE_MATCH_POLICIES.map((value) => ({
    value,
    label: t(`admin.collections.rule_match_policies.${value}`),
  }))
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
        <Field orientation="horizontal">
          <Controller
            control={form.control}
            name="automatic"
            render={({ field }) => (
              <Switch
                id="collection-automatic"
                checked={field.value}
                onCheckedChange={(checked) => {
                  field.onChange(checked)
                  // Give an automatic collection something to fill in rather
                  // than an empty rule list that matches nothing.
                  if (checked && rules.fields.length === 0) rules.append(newRule())
                }}
              />
            )}
          />
          <FieldLabel htmlFor="collection-automatic">
            {t('admin.collections.fields.automatic.label')}
          </FieldLabel>
        </Field>

        {automatic && (
          <div className="flex flex-col gap-3">
            <Controller
              control={form.control}
              name="rules_match_policy"
              render={({ field }) => (
                <Select
                  items={rulesMatchPolicyOptions}
                  value={field.value}
                  onValueChange={field.onChange}
                >
                  <SelectTrigger
                    id="collection-rules-match-policy"
                    data-size="sm"
                    className="w-auto self-start"
                    aria-label={t('admin.collections.fields.rules_match_policy.label')}
                  >
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

            {rules.fields.length > 0 && (
              // Plain rows with a rule between them: the card already frames
              // the rules, so each needs no box of its own.
              <div className="flex flex-col divide-y divide-border">
                {rules.fields.map((ruleField, index) => (
                  <div
                    key={ruleField.id}
                    className="flex flex-col gap-3 py-3 first:pt-0 last:pb-0 sm:flex-row sm:items-start"
                  >
                    <Field className="flex-1">
                      <Controller
                        control={form.control}
                        name={`rules.${index}.type`}
                        render={({ field }) => (
                          <Select
                            items={typeOptions}
                            value={field.value}
                            onValueChange={(type) => {
                              field.onChange(type)
                              // Each kind reads its value differently, so a
                              // tag left behind would mean nothing to "On sale".
                              const seed = ruleSeed(type as string)
                              form.setValue(`rules.${index}.value`, seed.value, {
                                shouldDirty: true,
                              })
                              form.setValue(`rules.${index}.match_policy`, seed.match_policy, {
                                shouldDirty: true,
                              })
                            }}
                          >
                            <SelectTrigger
                              aria-label={t('admin.collections.fields.rule_type.label')}
                            >
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
                    <RuleValueFields
                      form={form}
                      index={index}
                      matchPolicyOptions={matchPolicyOptions}
                    />
                    <Button
                      type="button"
                      variant="destructive-ghost"
                      size="icon"
                      aria-label={t('admin.collections.rules.remove')}
                      onClick={() => rules.remove(index)}
                    >
                      <Trash2Icon className="size-4" />
                    </Button>
                  </div>
                ))}
              </div>
            )}

            <Button
              type="button"
              variant="outline"
              size="sm"
              className="self-start"
              onClick={() => rules.append(newRule())}
            >
              <PlusIcon className="size-4" />
              {t('admin.collections.rules.add')}
            </Button>
          </div>
        )}
      </CardContent>
    </Card>
  )
}

type MatchPolicy = CollectionFormValues['rules'][number]['match_policy']

/** Where a rule of each kind starts, and what switching to it resets. */
function ruleSeed(type: string): { value: string; match_policy: MatchPolicy } {
  switch (type) {
    // The server ignores the value of an "On sale" rule but requires one;
    // the condition alone says on sale or not.
    case 'sale':
      return { value: 'true', match_policy: 'is_equal_to' }
    // Days back from today; only "is equal to" narrows anything.
    case 'available_on':
      return { value: '30', match_policy: 'is_equal_to' }
    default:
      return { value: '', match_policy: 'is_equal_to' }
  }
}

/** Splits a tag rule's value — tags joined by commas — into the tag list. */
function splitTags(value: string | undefined): string[] {
  return (value ?? '')
    .split(',')
    .map((tag) => tag.trim())
    .filter(Boolean)
}

/**
 * The condition and value of one rule, in the control its kind reads: tags
 * for a tag rule, a switch for "On sale", a number of days for "Recently
 * published", and a plain condition and text value for any other kind.
 */
function RuleValueFields({
  form,
  index,
  matchPolicyOptions,
}: {
  form: UseFormReturn<CollectionFormValues>
  index: number
  matchPolicyOptions: { value: string; label: string }[]
}) {
  const { t } = useTranslation()
  const { errors } = form.formState
  const type = form.watch(`rules.${index}.type`)
  const valueError = <FieldError errors={[errors.rules?.[index]?.value]} />

  if (type === 'sale') {
    return (
      <Field orientation="horizontal" className="flex-[2] sm:min-h-9 sm:items-center">
        <Controller
          control={form.control}
          name={`rules.${index}.match_policy`}
          render={({ field }) => (
            <Switch
              id={`collection-rule-on-sale-${index}`}
              checked={field.value !== 'is_not_equal_to'}
              onCheckedChange={(checked) =>
                field.onChange(checked ? 'is_equal_to' : 'is_not_equal_to')
              }
            />
          )}
        />
        <FieldLabel htmlFor={`collection-rule-on-sale-${index}`}>
          {t('admin.collections.rules.on_sale')}
        </FieldLabel>
      </Field>
    )
  }

  if (type === 'available_on') {
    return (
      <Field className="flex-[2]">
        <InputGroup>
          <InputGroupInput
            id={`collection-rule-value-${index}`}
            type="number"
            min={1}
            step={1}
            aria-label={t('admin.collections.rules.days_label')}
            aria-invalid={!!errors.rules?.[index]?.value || undefined}
            {...form.register(`rules.${index}.value`)}
          />
          <InputGroupAddon align="inline-end">
            <InputGroupText>{t('admin.collections.rules.days')}</InputGroupText>
          </InputGroupAddon>
        </InputGroup>
        {valueError}
      </Field>
    )
  }

  const policySelect = (
    <Field className="flex-1">
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
  )

  if (type === 'tag') {
    return (
      <>
        {policySelect}
        <Field className="flex-1">
          <Controller
            control={form.control}
            name={`rules.${index}.value`}
            render={({ field }) => (
              <TagCombobox
                taggableType="product"
                value={splitTags(field.value)}
                onChange={(tags) => field.onChange(tags.join(', '))}
                placeholder={t('admin.collections.rules.tags_placeholder')}
              />
            )}
          />
          {valueError}
        </Field>
      </>
    )
  }

  return (
    <>
      {policySelect}
      <Field className="flex-1">
        <Input
          id={`collection-rule-value-${index}`}
          aria-label={t('admin.collections.fields.rule_value.label')}
          placeholder={t('admin.collections.fields.rule_value.placeholder')}
          aria-invalid={!!errors.rules?.[index]?.value || undefined}
          {...form.register(`rules.${index}.value`)}
        />
        {valueError}
      </Field>
    </>
  )
}
