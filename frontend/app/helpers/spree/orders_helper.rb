module Spree
  module OrdersHelper
    def order_just_completed?(order)
      flash[:order_completed] && order.present?
    end

    def order_has_free_shipping?(order)
      order.promotions.
        joins(:promotion_actions).
        where(spree_promotion_actions: { type: 'Spree::Promotion::Actions::FreeShipping' }).
        exists?
    end
  end
end
