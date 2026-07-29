# frozen_string_literal: true

module Spree
  module PromotionRules
    # Deprecation alias for Spree::Promotion::Rules::Category, renamed from
    # Spree::Promotion::Rules::Taxon in 6.0. A true constant alias, so old STI type
    # strings (`'Spree::Promotion::Rules::Taxon'`) still instantiate correctly until
    # the Phase 4 migration rewrites them. The warning fires when this file loads.
    # Removed in 6.1.
    Taxon = Category

    Spree::Deprecation.warn('Spree::PromotionRules::Taxon is deprecated and will be removed in Spree 6.1. Use Spree::PromotionRules::Category instead.')
  end
end
