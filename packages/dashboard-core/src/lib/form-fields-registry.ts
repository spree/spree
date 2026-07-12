// Extension form fields — let host-app code and plugins add fields to a
// built-in resource form (product, category, …) that hydrate from the fetched
// resource and persist through the form's own Save. The host form spreads its
// values into the update payload, so a registered field's value reaches the
// API without any save code on the extension side; the backend only needs to
// permit the attribute.
//
// The registry solves the hydration half: built-in forms reset their values
// from a mapper over the fetched resource (which knows nothing about
// extension fields), so each form merges `extensionFormValues(formKey,
// resource)` into every defaultValues/reset object. The rendering half is a
// slot widget binding an input via `useHostForm()`.

/** One extension field on a built-in resource form. */
export interface FormFieldRegistration<TResource = unknown> {
  /**
   * The form value key — also the API attribute name submitted on save
   * (read/write symmetry: whatever the serializer exposes is what the
   * controller permits).
   */
  name: string
  /**
   * Seed the field's form value from the fetched resource. Receives `null`
   * on create forms (no resource yet) — return the field's blank value.
   */
  from: (resource: TResource | null) => unknown
}

const registrations = new Map<string, FormFieldRegistration[]>()

/**
 * Registry of extension fields per built-in form. Form keys match the form's
 * slot prefix — `'product'` for the product detail form. Registered names
 * must be unique per form; duplicates throw so two plugins can't silently
 * fight over one attribute.
 */
export const formFields = {
  register<TResource = unknown>(
    formKey: string,
    registration: FormFieldRegistration<TResource>,
  ): void {
    const list = registrations.get(formKey) ?? []
    if (list.some((r) => r.name === registration.name)) {
      throw new Error(
        `Form field "${registration.name}" is already registered on the "${formKey}" form.`,
      )
    }
    registrations.set(formKey, [...list, registration as FormFieldRegistration])
  },

  /** Remove a registered field. No-op when absent. */
  remove(formKey: string, name: string): void {
    const list = registrations.get(formKey)
    if (!list) return
    registrations.set(
      formKey,
      list.filter((r) => r.name !== name),
    )
  },
}

/**
 * Values for every extension field registered on `formKey`, seeded from
 * `resource` (or blanks when `null`). Built-in forms merge this into their
 * defaultValues and every hydration `reset(...)` so extension fields survive
 * refetch-driven resets.
 */
export function extensionFormValues(
  formKey: string,
  resource: unknown | null,
): Record<string, unknown> {
  const out: Record<string, unknown> = {}
  for (const registration of registrations.get(formKey) ?? []) {
    out[registration.name] = registration.from(resource)
  }
  return out
}

/**
 * Current values of every extension field registered on `formKey`, read from
 * live form state. Host forms spread this into their submit payload: the
 * form's Zod schema only knows first-party fields (its parse strips unknown
 * keys from the submitted values), so extension values are collected from
 * `form.getValues(...)` instead — which also keeps them out of client-side
 * schema validation. Their validation is the server's; a 422 maps back onto
 * the field via `mapSpreeErrorsToForm`.
 */
export function extensionSubmitValues(
  formKey: string,
  form: { getValues: (name: string) => unknown },
): Record<string, unknown> {
  const out: Record<string, unknown> = {}
  for (const registration of registrations.get(formKey) ?? []) {
    out[registration.name] = form.getValues(registration.name)
  }
  return out
}

/** Test-only: clear the registry. Not exported from the package index. */
export function __resetFormFieldsRegistry(): void {
  registrations.clear()
}
