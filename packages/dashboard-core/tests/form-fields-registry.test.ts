import { beforeEach, describe, expect, it } from 'vitest'
import {
  __resetFormFieldsRegistry,
  extensionFormValues,
  extensionSubmitValues,
  formFields,
} from '../src/lib/form-fields-registry'

interface FakeProduct {
  tech_specs?: string
}

describe('formFields registry', () => {
  beforeEach(() => {
    __resetFormFieldsRegistry()
  })

  it('seeds registered fields from the resource', () => {
    formFields.register<FakeProduct>('product', {
      name: 'tech_specs',
      from: (p) => p?.tech_specs ?? '',
    })

    expect(extensionFormValues('product', { tech_specs: 'RAM: 16GB' })).toEqual({
      tech_specs: 'RAM: 16GB',
    })
  })

  it('passes null on create forms so fields seed their blank value', () => {
    formFields.register<FakeProduct>('product', {
      name: 'tech_specs',
      from: (p) => p?.tech_specs ?? '',
    })

    expect(extensionFormValues('product', null)).toEqual({ tech_specs: '' })
  })

  it('returns an empty object for forms with no registrations', () => {
    expect(extensionFormValues('category', { anything: true })).toEqual({})
  })

  it('scopes registrations per form key', () => {
    formFields.register('product', { name: 'a', from: () => 1 })
    formFields.register('category', { name: 'b', from: () => 2 })

    expect(extensionFormValues('product', {})).toEqual({ a: 1 })
    expect(extensionFormValues('category', {})).toEqual({ b: 2 })
  })

  it('throws on a duplicate name within one form', () => {
    formFields.register('product', { name: 'tech_specs', from: () => '' })
    expect(() => formFields.register('product', { name: 'tech_specs', from: () => '' })).toThrow(
      /already registered/,
    )
  })

  it('collects submit values from live form state', () => {
    formFields.register('product', { name: 'tech_specs', from: () => '' })
    formFields.register('product', { name: 'warranty_months', from: () => null })

    const fakeForm = {
      getValues: (name: string) => ({ tech_specs: 'RAM: 16GB', warranty_months: 24 })[name],
    }

    expect(extensionSubmitValues('product', fakeForm)).toEqual({
      tech_specs: 'RAM: 16GB',
      warranty_months: 24,
    })
    expect(extensionSubmitValues('category', fakeForm)).toEqual({})
  })

  it('remove() unregisters and is a no-op when absent', () => {
    formFields.register('product', { name: 'tech_specs', from: () => '' })
    formFields.remove('product', 'tech_specs')
    expect(extensionFormValues('product', {})).toEqual({})
    expect(() => formFields.remove('product', 'missing')).not.toThrow()
  })
})
