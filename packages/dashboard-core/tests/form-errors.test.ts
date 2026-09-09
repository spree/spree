import { SpreeError } from '@spree/admin-sdk'
import i18n from 'i18next'
import { beforeAll, describe, expect, it, vi } from 'vitest'
import { mapSpreeErrorsToForm } from '../src/lib/form-errors'

function spreeError(details: Record<string, unknown[]>, message = 'Something went wrong') {
  return new SpreeError({ error: { code: 'validation_error', message, details } } as never, 422)
}

beforeAll(async () => {
  await i18n.init({
    lng: 'en',
    resources: {
      en: {
        translation: {
          admin: {
            validation: {
              // Client-side keys the forms' own schemas read stay beside the
              // server codes — proof the two namespaces do not collide.
              required: '{{field}} is required',
              codes: {
                blank: 'Required',
                invalid: 'Is not valid',
                greater_than: 'Must be more than {{count}}',
                // Per-attribute overrides of a shared code.
                quantity: { blank: 'Enter how many' },
                callback_url: { invalid: 'Enter a full web address' },
              },
            },
            fields: {
              name: { label: 'Name' },
              quantity: { label: 'Quantity' },
              callback_url: { label: 'Callback URL' },
            },
          },
        },
      },
    },
  })
})

describe('mapSpreeErrorsToForm', () => {
  it('translates the error code rather than showing the server message', () => {
    const setError = vi.fn()
    mapSpreeErrorsToForm(
      spreeError({ name: [{ code: 'blank', message: "can't be blank" }] }),
      setError,
    )

    expect(setError).toHaveBeenCalledWith('name', { type: 'server', message: 'Required' })
  })

  it("interpolates the validation's own values into the translation", () => {
    const setError = vi.fn()
    mapSpreeErrorsToForm(
      spreeError({
        price: [{ code: 'greater_than', message: 'must be greater than 0', count: 0 }],
      }),
      setError,
    )

    expect(setError).toHaveBeenCalledWith('price', {
      type: 'server',
      message: 'Must be more than 0',
    })
  })

  it('prefers a per-attribute key over the general one', () => {
    const setError = vi.fn()
    mapSpreeErrorsToForm(
      spreeError({ quantity: [{ code: 'blank', message: "can't be blank" }] }),
      setError,
    )

    expect(setError).toHaveBeenCalledWith('quantity', {
      type: 'server',
      message: 'Enter how many',
    })
  })

  it("falls back to the server's message for a code it has no translation for", () => {
    // The extension case: a gem validates something the dashboard never heard of.
    const setError = vi.fn()
    mapSpreeErrorsToForm(
      spreeError({ sku: [{ code: 'reserved_by_supplier', message: 'is claimed by a supplier' }] }),
      setError,
    )

    expect(setError).toHaveBeenCalledWith('sku', {
      type: 'server',
      message: 'is claimed by a supplier',
    })
  })

  it('renders a message that carries no code', () => {
    const setError = vi.fn()
    mapSpreeErrorsToForm(spreeError({ sku: [{ code: null, message: 'is not usable' }] }), setError)

    expect(setError).toHaveBeenCalledWith('sku', { type: 'server', message: 'is not usable' })
  })

  it('still reads the flat string shape', () => {
    // Older payloads, and anything proxied from the Store API.
    const setError = vi.fn()
    mapSpreeErrorsToForm(spreeError({ name: ["can't be blank"] }), setError)

    expect(setError).toHaveBeenCalledWith('name', { type: 'server', message: "can't be blank" })
  })

  it('keeps record-level and nested errors on the root summary', () => {
    const setError = vi.fn()
    mapSpreeErrorsToForm(
      spreeError({
        base: [{ code: 'order_cannot_be_deleted', message: 'cannot be deleted' }],
        'line_items.0.quantity': [{ code: 'blank', message: "can't be blank" }],
      }),
      setError,
    )

    const fields = setError.mock.calls.map(([field]) => field)
    expect(fields).toEqual(['root'])
  })

  it('returns false for anything that is not a SpreeError', () => {
    const setError = vi.fn()
    expect(mapSpreeErrorsToForm(new TypeError('offline'), setError)).toBe(false)
    expect(setError).not.toHaveBeenCalled()
  })
})

describe('specific server copy', () => {
  it('keeps a model message the server marked as its own wording', () => {
    // The webhook URL validation reports `invalid`, but its message says what
    // a valid URL looks like. Rendering the generic key would lose that.
    const setError = vi.fn()
    mapSpreeErrorsToForm(
      spreeError({
        url: [{ code: 'invalid', message: 'must be a valid http or https URL', specific: true }],
      }),
      setError,
    )

    expect(setError).toHaveBeenCalledWith('url', {
      type: 'server',
      message: 'must be a valid http or https URL',
    })
  })

  it('translates the code when the message is the code default', () => {
    const setError = vi.fn()
    mapSpreeErrorsToForm(
      spreeError({ sku: [{ code: 'invalid', message: 'is invalid', specific: false }] }),
      setError,
    )

    expect(setError).toHaveBeenCalledWith('sku', { type: 'server', message: 'Is not valid' })
  })

  it('translates a code default that the server resolved in the store locale', () => {
    // The regression this contract exists for: on a German store `blank`
    // arrives as "darf nicht leer sein", which no English comparison could
    // recognise as the default. The server's flag says so in any locale.
    const setError = vi.fn()
    mapSpreeErrorsToForm(
      spreeError({ name: [{ code: 'blank', message: 'darf nicht leer sein', specific: false }] }),
      setError,
    )

    expect(setError).toHaveBeenCalledWith('name', { type: 'server', message: 'Required' })
  })
})

describe('the summary banner', () => {
  it("is rebuilt in the admin's language when every entry translated", () => {
    const setError = vi.fn()
    mapSpreeErrorsToForm(
      spreeError(
        {
          name: [{ code: 'blank', message: "can't be blank" }],
          quantity: [{ code: 'greater_than', message: 'must be greater than 0', count: 0 }],
        },
        "Name can't be blank, Quantity must be greater than 0",
      ),
      setError,
    )

    const root = setError.mock.calls.find(([field]) => field === 'root')
    expect(root?.[1].message).toBe('Name Required, Quantity Must be more than 0')
  })

  it("keeps the server's sentence when an entry has no translation", () => {
    // Half-rebuilding would drop the untranslated failure from the summary.
    const setError = vi.fn()
    mapSpreeErrorsToForm(
      spreeError(
        {
          name: [{ code: 'blank', message: "can't be blank" }],
          sku: [{ code: 'reserved_by_supplier', message: 'is claimed by a supplier' }],
        },
        "Name can't be blank, Sku is claimed by a supplier",
      ),
      setError,
    )

    const root = setError.mock.calls.find(([field]) => field === 'root')
    expect(root?.[1].message).toBe("Name can't be blank, Sku is claimed by a supplier")
  })
})

describe('the banner and the field agree', () => {
  it('uses a per-attribute key in both, even for a message the model worded', () => {
    // The banner used to bail on any `specific` entry while the field below it
    // rendered the per-attribute translation, so the two disagreed.
    const setError = vi.fn()
    mapSpreeErrorsToForm(
      spreeError(
        {
          callback_url: [
            { code: 'invalid', message: 'must be a valid http or https URL', specific: true },
          ],
        },
        'Callback url must be a valid http or https URL',
      ),
      setError,
    )

    const field = setError.mock.calls.find(([f]) => f === 'callback_url')
    const root = setError.mock.calls.find(([f]) => f === 'root')
    expect(field?.[1].message).toBe('Enter a full web address')
    expect(root?.[1].message).toBe('Callback URL Enter a full web address')
  })
})
