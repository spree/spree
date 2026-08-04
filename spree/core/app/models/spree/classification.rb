# frozen_string_literal: true

module Spree
  # Deprecation alias for Spree::ProductCategory, renamed from Spree::Classification
  # in 6.0. A true constant alias (AR-safe); the warning fires when this file loads.
  # Removed in 6.1.
  Classification = ProductCategory

  Spree::Deprecation.warn('Spree::Classification is deprecated and will be removed in Spree 6.1. Use Spree::ProductCategory instead.')
end
