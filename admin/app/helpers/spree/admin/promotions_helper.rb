module Spree
  module Admin
    module PromotionsHelper
      def promotion_filter_dropdown_value
        if params.dig(:q, :expired)
          Spree.t(:expired)
        elsif params.dig(:q, :active)
          Spree.t(:active)
        else
          Spree.t(:all)
        end
      end

      def promotion_status(promotion)
        if promotion.active?
          Spree.t(:active)
        elsif promotion.expired?
          Spree.t(:expired)
        elsif promotion.inactive?
          Spree.t(:inactive)
        end
      end
    end
  end
end
