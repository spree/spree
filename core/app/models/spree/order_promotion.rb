module Spree
  class OrderPromotion < Spree::Base
    self.table_name = 'spree_orders_promotions'

    belongs_to :order, class_name: 'Spree::Order'
    belongs_to :promotion, class_name: 'Spree::Promotion'
  end
end
