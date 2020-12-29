module Spree
  class OrderPromotion < Spree::Base
    belongs_to :order, class_name: 'Spree::Order'
    belongs_to :promotion, class_name: 'Spree::Promotion'

    delegate :name, :description, :code, to: :promotion
    delegate :currency, to: :order

    extend Spree::DisplayMoney
    money_methods :amount

    def amount
      order.all_adjustments.promotion.where(source: promotion.actions).sum(:amount)
    end
  end
end
