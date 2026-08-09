# frozen_string_literal: true

module Spree
  # Deprecation alias for Spree::CustomFieldDefinition, renamed from
  # Spree::MetafieldDefinition in 6.0. Retained for one release; removed in 6.1.
  #
  # Note the columns renamed alongside the class: `name` is now `label`,
  # `metafield_type` is now `field_type` (which reads back an API token such as
  # `short_text` rather than the STI class name), and the tri-state `display_on`
  # collapsed into the `storefront_visible` boolean.
  MetafieldDefinition = CustomFieldDefinition

  Spree::Deprecation.warn('Spree::MetafieldDefinition is deprecated and will be removed in Spree 6.1. Use Spree::CustomFieldDefinition instead.')
end
