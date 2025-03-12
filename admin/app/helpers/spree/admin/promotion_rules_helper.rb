module Spree
  module Admin
    module PromotionRulesHelper
      def options_for_promotion_rule_types(promotion)
        existing = promotion.rules.map { |rule| rule.class.name }
        Rails.application.config.spree.promotions.rules.map(&:name).reject { |r| existing.include? r }
      end

      def active_options_for_option_value_promotion_rule(promotion_rule)
        eligible_values = promotion_rule.preferred_eligible_values || []
        return [] if eligible_values.empty?

        Spree::OptionValueVariant.where(id: eligible_values).to_tom_select_json
      end
    end
  end
end
