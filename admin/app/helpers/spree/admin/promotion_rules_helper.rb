module Spree
  module Admin
    module PromotionRulesHelper
      def options_for_promotion_rule_types(promotion)
        existing = promotion.rules.pluck(:type)
        Spree.promotions.rules.map(&:name).reject { |r| existing.include? r }
      end

      def active_options_for_option_value_promotion_rule(promotion_rule)
        eligible_values = promotion_rule.preferred_eligible_values || []
        return [] if eligible_values.empty?

        Spree::OptionValue.includes(:option_type).where(id: eligible_values).map do |ov|
          {
            id: ov.id,
            name: ov.display_presentation
          }
        end
      end

      # Returns the promotion rule option values
      # @param value_ids [Array<Integer>]
      # @return [Array<String>]
      def promotion_rule_option_values(value_ids)
        Spree::OptionValue.includes(:option_type).where(id: value_ids).map(&:display_presentation)
      end
    end
  end
end
