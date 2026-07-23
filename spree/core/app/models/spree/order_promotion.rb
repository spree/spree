module Spree
  class OrderPromotion < Spree.base_class
    has_prefix_id :discount

    belongs_to :order, class_name: 'Spree::Order'
    belongs_to :promotion, class_name: 'Spree::Promotion'

    delegate :name, :description, :code, :public_metadata, to: :promotion
    delegate :currency, to: :order

    validates :order, :promotion, presence: true
    validates :order, uniqueness: { scope: :promotion }

    extend Spree::DisplayMoney
    money_methods :amount

    # Winner-only discount lines make this reconcile with the order's
    # discount_total by construction (losing candidates are deleted, not
    # flagged ineligible as legacy adjustments were).
    def amount
      order.discount_lines.where(promotion_id: promotion_id).sum(:amount)
    end
  end
end
