# frozen_string_literal: true

module Spree
  # Deprecation alias for Spree::CustomField, renamed from Spree::Metafield in
  # 6.0. Retained for one release so existing code and extensions that reference
  # Spree::Metafield keep working; the canonical class is Spree::CustomField.
  # Removed in 6.1.
  #
  # This is a true constant alias — the underlying class, table
  # (spree_custom_fields), prefix (cf) and model_name are all
  # Spree::CustomField. Only the constant differs, so is_a?, STI, polymorphic
  # *_type strings and class_name: references keep resolving to
  # Spree::CustomField.
  Metafield = CustomField

  Spree::Deprecation.warn('Spree::Metafield is deprecated and will be removed in Spree 6.1. Use Spree::CustomField instead.')
end
