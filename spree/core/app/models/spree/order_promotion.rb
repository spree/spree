module Spree
  class OrderPromotion < Spree.base_class
    belongs_to :order, class_name: 'Spree::Order'
    belongs_to :promotion, class_name: 'Spree::Promotion'

    delegate :name, :description, :code, :public_metadata, to: :promotion
    delegate :currency, to: :order

    validates :order, :promotion, presence: true
    validates :order, uniqueness: { scope: :promotion }

    extend Spree::DisplayMoney
    money_methods :amount

    def amount
      order.all_adjustments.promotion.where(source: promotion.actions).sum(:amount)
    end
  end
end
