# frozen_string_literal: true

module Spree
  class Promotion
    module Rules
      # Deprecation alias for Spree::Promotion::Rules::Category, renamed from
      # Spree::Promotion::Rules::Taxon in 6.0. Old STI type strings still resolve
      # through this alias until the Phase 4 data migration rewrites them. Removed in 6.1.
      Taxon = Category
    end
  end
end
