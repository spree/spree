import type { CustomFieldDefinition } from '@spree/admin-sdk'
import { adminClient } from '@spree/dashboard-core'
import i18n from 'i18next'

/**
 * A definition's own label, falling back to the key an operator typed when
 * they never gave it one, with the namespaced key alongside — two fields can
 * share a label across namespaces, and the key is what tells them apart.
 */
export function customFieldDefinitionLabel(definition: CustomFieldDefinition): string {
  const key = `${definition.namespace}.${definition.key}`

  return definition.label ? `${definition.label} (${key})` : key
}

/**
 * Autocomplete over the custom fields defined for one resource — the shared
 * config a `<ResourceMultiAutocomplete>` needs bar the value/onChange the
 * form supplies.
 *
 * Scoped by `resource_type` so a picker for seller onboarding cannot offer a
 * field defined for products, which a seller has nowhere to answer.
 */
export function customFieldDefinitionAutocompleteProps(resourceType: string) {
  return (queryKey: string) => ({
    queryKey,
    search: (q: string) =>
      adminClient.customFieldDefinitions.list({
        resource_type_eq: resourceType,
        label_or_key_cont: q,
        limit: 20,
        sort: 'key',
      }),
    hydrate: (ids: string[]) =>
      adminClient.customFieldDefinitions.list({ id_in: ids, limit: ids.length }),
    getOptionLabel: customFieldDefinitionLabel,
    placeholder: i18n.t('admin.seller_requirements.fields.custom_fields.placeholder'),
    emptyText: i18n.t('admin.seller_requirements.fields.custom_fields.empty'),
  })
}
