module Spree
  module Admin
    module PromotionsHelper
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
