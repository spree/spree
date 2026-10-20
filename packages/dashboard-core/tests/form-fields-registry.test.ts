import { beforeEach, describe, expect, it } from 'vitest'
import {
  __resetFormFieldsRegistry,
  extensionFormValues,
  extensionRowValues,
  extensionSubmitValues,
  formFields,
} from '../src/lib/form-fields-registry'
import {
  mediaToFormValues,
  variantToWirePayload,
  withExtensionRowValues,
} from '../src/products/product-form-mapping'
import type { ProductFormValues, VariantFormValues } from '../src/products/product-schema'

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

  it('picks only the registered fields a row holds', () => {
    formFields.register('product.media', { name: 'credit', from: () => '' })
    formFields.register('product.media', { name: 'license', from: () => null })

    expect(extensionRowValues('product.media', { alt: 'Front', credit: 'Jane' })).toEqual({
      credit: 'Jane',
    })
    expect(extensionRowValues('product.media', undefined)).toEqual({})
  })

  it('carries row fields from the API record through the form and back out', () => {
    formFields.register('product.media', {
      name: 'credit',
      from: (media) => (media as { credit?: string } | null)?.credit ?? '',
    })
    formFields.register('product.variant', { name: 'brand_code', from: () => '' })

    expect(mediaToFormValues({ id: 'media_1', credit: 'Jane' } as never, 0)).toMatchObject({
      id: 'media_1',
      credit: 'Jane',
    })

    // The parse strips unknown keys from every row; live form state has them.
    const parsed = {
      name: 'Shirt',
      media: [{ id: 'media_1', alt: 'Front' }],
      variants: [{ position: 0, options: [] }],
    } as ProductFormValues
    const raw = {
      media: [{ id: 'media_1', alt: 'Front', credit: 'Jane' }],
      variants: [{ position: 0, options: [], brand_code: 'ACME' }],
    } as unknown as ProductFormValues
    const restored = withExtensionRowValues('product', parsed, raw)

    expect(restored.media?.[0]).toMatchObject({ credit: 'Jane' })
    expect(variantToWirePayload(restored.variants?.[0] as VariantFormValues, 0)).toMatchObject({
      brand_code: 'ACME',
      position: 1,
    })
  })

  it('keeps each panel to its own row fields', () => {
    formFields.register('seller.product.variant', { name: 'brand_code', from: () => '' })
    const variant = { position: 0, options: [], brand_code: 'ACME' } as VariantFormValues

    expect(variantToWirePayload(variant, 0)).not.toHaveProperty('brand_code')
    expect(variantToWirePayload(variant, 0, 'seller.product')).toMatchObject({ brand_code: 'ACME' })
  })

  it('remove() unregisters and is a no-op when absent', () => {
    formFields.register('product', { name: 'tech_specs', from: () => '' })
    formFields.remove('product', 'tech_specs')
    expect(extensionFormValues('product', {})).toEqual({})
    expect(() => formFields.remove('product', 'missing')).not.toThrow()
  })
})
