# frozen_string_literal: true

module Spree
  # Deprecation alias for Spree::ProductCategory, renamed from Spree::Classification
  # in 6.0. Kept for one release so existing references keep resolving; removed in 6.1.
  Classification = ProductCategory
end
