# frozen_string_literal: true

module Spree
  # Deprecation alias for Spree::PromotionRuleCategory, renamed from
  # Spree::PromotionRuleTaxon in 6.0. Kept for one release; removed in 6.1.
  PromotionRuleTaxon = PromotionRuleCategory
end
