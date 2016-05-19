module Spree
  module Admin
    module PromotionRulesHelper
      def options_for_promotion_rule_types(promotion)
        existing = promotion.rules.map { |rule| rule.class.name }
        rule_names = Rails.application.config.spree.promotions.rules.map(&:name).reject { |r| existing.include? r }
        options = rule_names.map { |name| [Spree.t("promotion_rule_types.#{name.demodulize.underscore}.name"), name] }
        options_for_select(options)
      end
    end
  end
end
