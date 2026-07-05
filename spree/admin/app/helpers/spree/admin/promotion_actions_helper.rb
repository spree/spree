module Spree
  module Admin
    module PromotionActionsHelper
      def options_for_promotion_action_types(promotion)
        existing = promotion.actions.pluck(:type)
        Spree.promotions.actions.map(&:name).reject { |r| existing.include? r }
      end
    end
  end
end
