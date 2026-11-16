import type { CustomFieldDefinition } from '@spree/admin-sdk'
import { describe, expect, it } from 'vitest'
import {
  CUSTOM_FIELD_DEFINITION_DEFAULTS,
  customFieldDefinitionSchema,
  customFieldDefinitionValuesToCreateParams,
  customFieldValueError,
} from './custom-field-definition'

const definition = (
  field_type: CustomFieldDefinition['field_type'],
  validations: Partial<CustomFieldDefinition['validations']> = {},
) =>
  ({
    field_type,
    validations: {
      required: false,
      min: null,
      max: null,
      multiple: false,
      choices: [],
      ...validations,
    },
  }) as CustomFieldDefinition

describe('customFieldValueError', () => {
  it('checks required only when asked', () => {
    const required = definition('short_text', { required: true })

    expect(customFieldValueError(required, '')).toBeNull()
    expect(customFieldValueError(required, '  ', { checkRequired: true })).not.toBeNull()
    expect(customFieldValueError(required, 'set', { checkRequired: true })).toBeNull()
  })

  it('checks text length, numbers, dates and date-times against their bounds', () => {
    expect(customFieldValueError(definition('short_text', { max: 3 }), 'abcd')).not.toBeNull()
    expect(customFieldValueError(definition('number', { min: 1 }), 0)).not.toBeNull()
    expect(customFieldValueError(definition('number', { min: 1 }), 1)).toBeNull()
    expect(
      customFieldValueError(definition('date', { max: '2026-12-31' }), '2027-01-01'),
    ).not.toBeNull()
    expect(
      customFieldValueError(
        definition('date_time', { min: '2026-10-12T08:00:00Z' }),
        '2026-10-12T07:59:00.000Z',
      ),
    ).not.toBeNull()
  })

  it('refuses a value that is not one of the choices', () => {
    const choice = definition('choice', { choices: [{ value: 'a', label: 'A' }], multiple: true })

    expect(customFieldValueError(choice, ['a'])).toBeNull()
    expect(customFieldValueError(choice, ['a', 'z'])).not.toBeNull()
  })
})

describe('customFieldDefinitionSchema', () => {
  const choiceForm = (choices: { value: string; label: string }[]) => ({
    ...CUSTOM_FIELD_DEFINITION_DEFAULTS,
    label: 'Zone',
    key: 'zone',
    field_type: 'choice' as const,
    validations: { ...CUSTOM_FIELD_DEFINITION_DEFAULTS.validations, choices },
  })

  it('asks a choice field for at least one choice, each with a distinct value', () => {
    expect(customFieldDefinitionSchema.safeParse(choiceForm([])).success).toBe(false)
    expect(
      customFieldDefinitionSchema.safeParse(
        choiceForm([
          { value: 'a', label: '' },
          { value: 'a', label: '' },
        ]),
      ).success,
    ).toBe(false)
    expect(
      customFieldDefinitionSchema.safeParse(choiceForm([{ value: 'a', label: '' }])).success,
    ).toBe(true)
  })

  it('sends only the rules the field type takes', () => {
    const params = customFieldDefinitionValuesToCreateParams({
      ...CUSTOM_FIELD_DEFINITION_DEFAULTS,
      field_type: 'boolean',
      validations: { required: true, min: '2', max: '', multiple: true, choices: [] },
    })

    expect(params.validations).toEqual({ required: true })
    expect(
      customFieldDefinitionValuesToCreateParams(CUSTOM_FIELD_DEFINITION_DEFAULTS).validations,
    ).toBeNull()
  })
})
