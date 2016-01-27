module Spree
  module PromotionRulesHelper

    def options_for_promotion_rule_types(promotion)
      rule_names = Rails.application.config.spree.promotions.rules.map(&:name)
      options = rule_names.map { |name| [ Spree.t("promotion_rule_types.#{name.demodulize.underscore}.name"), name] }
      options_for_select(options)
    end

  end
end

