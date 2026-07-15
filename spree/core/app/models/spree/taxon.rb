# frozen_string_literal: true

module Spree
  # Deprecation alias for Spree::Category, renamed from Spree::Taxon in 6.0.
  # Retained for one release so existing code and extensions that reference
  # Spree::Taxon keep working; the canonical class is Spree::Category. Removed
  # in 6.1 (along with the spree_taxonomies table and the automatic-taxon columns).
  #
  # This is a true constant alias — the underlying class, table (spree_categories),
  # prefix (ctg), and model_name are all Spree::Category. Only the constant differs,
  # so is_a?, STI, polymorphic *_type strings, and class_name: references keep
  # resolving to Spree::Category. The warning below fires through Spree's deprecator
  # when this file loads (at boot under eager load, on first reference otherwise).
  Taxon = Category

  Spree::Deprecation.warn('Spree::Taxon is deprecated and will be removed in Spree 6.1. Use Spree::Category instead.')
end
