import type { PromotionActionCalculator } from '@spree/admin-sdk'
import { useQuery } from '@tanstack/react-query'
import { useEffect, useMemo, useState } from 'react'
import { adminClient } from '@/client'
import { PreferencesForm } from '@/components/spree/preferences-form'
import { Field, FieldGroup, FieldLabel } from '@/components/ui/field'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { EditorShell } from './editor-shell'
import type { PromotionActionEditorContext } from './types'

/**
 * Editor for `Spree::Promotion::Actions::CreateAdjustment` and
 * `CreateItemAdjustments`. Both wrap a Calculator: the merchant picks
 * the subclass, the form below renders that calculator's preferences.
 */
export function AdjustmentActionEditor({ draft, onSave, onClose }: PromotionActionEditorContext) {
  const { data: calculatorsData, isLoading: calculatorsLoading } = useQuery({
    queryKey: ['promotion-action-calculators', draft.type],
    queryFn: () => adminClient.promotionActions.calculators(draft.type),
  })

  const calculators = calculatorsData?.data ?? []

  const [calculatorType, setCalculatorType] = useState<string>(() => draft.calculator?.type ?? '')
  const [preferences, setPreferences] = useState<Record<string, unknown>>(
    () => draft.calculator?.preferences ?? {},
  )

  // Once the catalog arrives, ensure `calculatorType` points at a known
  // calculator. Falls back to the first entry if the draft has no
  // calculator yet (newly-picked action) or carries a removed one.
  useEffect(() => {
    if (calculators.length === 0) return
    const matches = calculators.some((c) => c.type === calculatorType)
    if (!matches) setCalculatorType(calculators[0].type)
  }, [calculators, calculatorType])

  const selectedCalculator: PromotionActionCalculator | undefined = useMemo(
    () => calculators.find((c) => c.type === calculatorType),
    [calculators, calculatorType],
  )

  // Type changes swap the schema; previous preferences won't fit.
  function handleCalculatorChange(nextType: string) {
    if (nextType === calculatorType) return
    const next = calculators.find((c) => c.type === nextType)
    setCalculatorType(nextType)
    setPreferences(
      Object.fromEntries(
        (next?.preference_schema ?? []).map((field) => [field.key, field.default ?? '']),
      ),
    )
  }

  function handleSave() {
    if (!calculatorType) return
    onSave({
      ...draft,
      calculator: {
        type: calculatorType,
        preferences,
        // Display-only — lets `<ActionSummary>` render the row preview
        // without fetching `/calculators` again. Stripped at payload time.
        label: selectedCalculator?.label,
        preference_schema: selectedCalculator?.preference_schema,
      },
    })
    onClose()
  }

  return (
    <EditorShell
      onSave={handleSave}
      onCancel={onClose}
      pending={false}
      saveDisabled={!calculatorType}
    >
      <FieldGroup>
        <Field>
          <FieldLabel htmlFor="calculator-type">Calculator</FieldLabel>
          <Select
            value={calculatorType}
            onValueChange={handleCalculatorChange}
            disabled={calculatorsLoading || calculators.length === 0}
          >
            <SelectTrigger id="calculator-type">
              <SelectValue
                placeholder={calculatorsLoading ? 'Loading calculators…' : 'Select a calculator'}
              >
                {(value) => calculators.find((c) => c.type === value)?.label ?? (value as string)}
              </SelectValue>
            </SelectTrigger>
            <SelectContent>
              {calculators.map((calculator) => (
                <SelectItem key={calculator.type} value={calculator.type}>
                  {calculator.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </Field>
      </FieldGroup>

      {selectedCalculator && (
        <CalculatorPreferences
          calculator={selectedCalculator}
          values={preferences}
          onChange={setPreferences}
        />
      )}
    </EditorShell>
  )
}

function CalculatorPreferences({
  calculator,
  values,
  onChange,
}: {
  calculator: PromotionActionCalculator
  values: Record<string, unknown>
  onChange: (next: Record<string, unknown>) => void
}) {
  if (!calculator.preference_schema?.length) {
    return <p className="text-sm text-muted-foreground">This calculator has no extra settings.</p>
  }

  return (
    <FieldGroup>
      <FieldLabel>Calculator settings</FieldLabel>
      <PreferencesForm schema={calculator.preference_schema} values={values} onChange={onChange} />
    </FieldGroup>
  )
}
