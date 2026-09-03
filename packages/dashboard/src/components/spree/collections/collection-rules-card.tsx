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
import { typeLabel } from '../../../lib/type-labels'
import {
  blankCollectionRule,
  COLLECTION_RULE_MATCH_POLICIES,
  COLLECTION_RULES_MATCH_POLICIES,
  type CollectionFormValues,
} from '../../../schemas/collection'

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
    label: typeLabel('collection_rule_types', ruleType.type, ruleType.label),
  }))

  // Seed a new row from the registry so the Select always shows a real option,
  // even on a deployment that doesn't register the schema's default kind.
  const newRule = () => ({
    ...blankCollectionRule(),
    ...(typeOptions[0] ? { type: typeOptions[0].value } : {}),
  })
  const matchPolicyOptions = COLLECTION_RULE_MATCH_POLICIES.map((value) => ({
    value,
    label: t(`admin.collections.rule_match_policies.${value}`),
  }))
  const rulesMatchPolicyOptions = COLLECTION_RULES_MATCH_POLICIES.map((value) => ({
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
          <>
            <Field>
              <FieldLabel>{t('admin.collections.fields.rules_match_policy.label')}</FieldLabel>
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

            <div className="flex flex-col gap-3">
              {rules.fields.map((ruleField, index) => (
                <div
                  key={ruleField.id}
                  className="flex flex-col gap-3 rounded-lg border border-border p-3 sm:flex-row sm:items-start"
                >
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
                          onValueChange={field.onChange}
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
                        <Select
                          items={matchPolicyOptions}
                          value={field.value}
                          onValueChange={field.onChange}
                        >
                          <SelectTrigger
                            aria-label={t('admin.collections.fields.rule_match_policy.label')}
                          >
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

                  <Field className="flex-1">
                    <FieldLabel className="sr-only" htmlFor={`collection-rule-value-${index}`}>
                      {t('admin.collections.fields.rule_value.label')}
                    </FieldLabel>
                    <Input
                      id={`collection-rule-value-${index}`}
                      placeholder={t('admin.collections.fields.rule_value.placeholder')}
                      aria-invalid={!!errors.rules?.[index]?.value || undefined}
                      {...form.register(`rules.${index}.value`)}
                    />
                    <FieldError errors={[errors.rules?.[index]?.value]} />
                  </Field>

                  <Button
                    type="button"
                    variant="ghost"
                    size="icon"
                    aria-label={t('admin.collections.rules.remove')}
                    onClick={() => rules.remove(index)}
                  >
                    <Trash2Icon className="size-4" />
                  </Button>
                </div>
              ))}

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
          </>
        )}
      </CardContent>
    </Card>
  )
}
