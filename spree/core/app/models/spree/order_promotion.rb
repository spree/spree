module Spree
  class OrderPromotion < Spree.base_class
    has_prefix_id :discount

    # Owner — exactly one (cart during checkout, copied to the order at
    # completion)
    belongs_to :order, class_name: 'Spree::Order', optional: true, inverse_of: :order_promotions
    belongs_to :cart, class_name: 'Spree::Cart', optional: true, inverse_of: :order_promotions
    belongs_to :promotion, class_name: 'Spree::Promotion'

    delegate :name, :description, :code, to: :promotion
    delegate :currency, to: :owner

    validates :order, uniqueness: { scope: :promotion }, allow_nil: true
    validates :cart, uniqueness: { scope: :promotion }, allow_nil: true
    validate :exactly_one_owner

    extend Spree::DisplayMoney
    money_methods :amount

    # @return [Spree::Cart, Spree::Order, nil]
    def owner
      order || cart
    end

    # Bridge for legacy callers assigning +current_order+ (now a Spree::Cart)
    # to the order association — routes carts to the cart FK instead.
    def order=(record)
      if record.is_a?(Spree::Cart)
        self.cart = record
        super(nil)
      else
        super
      end
    end

    def amount
      owner.discounts.promotion.where(promotion_action_id: promotion.actions.ids).sum(:amount)
    end

    private

    def exactly_one_owner
      errors.add(:base, :exactly_one_of_cart_or_order, message: Spree.t('errors.messages.exactly_one_of_cart_or_order')) unless [order, cart].compact.one?
    end
  end
end
