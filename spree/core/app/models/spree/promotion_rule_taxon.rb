# frozen_string_literal: true

module Spree
  # Deprecation alias for Spree::PromotionRuleCategory, renamed from
  # Spree::PromotionRuleTaxon in 6.0. A true constant alias (AR-safe); the warning
  # fires when this file loads. Removed in 6.1.
  PromotionRuleTaxon = PromotionRuleCategory

  Spree::Deprecation.warn('Spree::PromotionRuleTaxon is deprecated and will be removed in Spree 6.1. Use Spree::PromotionRuleCategory instead.')
end
