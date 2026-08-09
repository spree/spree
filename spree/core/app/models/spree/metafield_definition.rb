# frozen_string_literal: true

module Spree
  # Deprecation alias for Spree::CustomFieldDefinition, renamed from
  # Spree::MetafieldDefinition in 6.0. Retained for one release; removed in 6.1.
  # A plain constant alias for the same reason as {Spree::Metafield}.
  #
  # Note the columns renamed alongside the class: `name` is now `label`,
  # `metafield_type` is now `field_type` (which reads back an API token such as
  # `short_text` rather than the STI class name), and the tri-state `display_on`
  # collapsed into the `storefront_visible` boolean.
  MetafieldDefinition = CustomFieldDefinition
end
