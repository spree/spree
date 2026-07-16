import type { CustomFieldDefinition } from '@spree/admin-sdk'
import type { ComponentType } from 'react'

/**
 * Props a custom field input component receives from the custom-fields card.
 * The component is a controlled input: render `value`, call `onChange` with
 * the next value — hydration and persistence are the card's concern (the
 * page form's Save for products/categories, the card's own Save elsewhere).
 */
export interface CustomFieldComponentProps {
  /** DOM id — wire it to your input for the card's `<label htmlFor>`. */
  id: string
  ariaLabel: string
  value: unknown
  onChange: (value: unknown) => void
  /** The full definition (field_type, config, namespace, key, …). */
  definition: CustomFieldDefinition
}

export type CustomFieldComponent = ComponentType<CustomFieldComponentProps>

const components = new Map<string, CustomFieldComponent>()

/**
 * Replace the input widget for a specific custom field definition, keyed by
 * its `namespace.key` identity (e.g. `'specs.color'`). When no component is
 * registered for a definition, the default widget for its `field_type`
 * renders — registering is purely additive.
 *
 * Keying by the definition's own identity (rather than a separate component
 * ID the definition would reference) means there's no stringly-typed
 * indirection to typo: the plugin that ships the definition registers the
 * component for it in the same breath.
 */
export const customFieldComponents = {
  register(namespaceDotKey: string, component: CustomFieldComponent): void {
    if (components.has(namespaceDotKey)) {
      throw new Error(`A custom field component is already registered for "${namespaceDotKey}".`)
    }
    components.set(namespaceDotKey, component)
  },

  get(namespaceDotKey: string): CustomFieldComponent | undefined {
    return components.get(namespaceDotKey)
  },

  /** Remove a registered component. No-op when absent. */
  remove(namespaceDotKey: string): void {
    components.delete(namespaceDotKey)
  },
}

/** Test-only: clear the registry. Not exported from the package index. */
export function __resetCustomFieldComponents(): void {
  components.clear()
}
