module Spree
  # Shared shape of the typed adjustment rows (TaxLine, Discount, Fee):
  # dual-FK cart/order owner (exactly one), consolidated +metadata+ JSON
  # column, money display and localized amount parsing.
  module TypedAdjustmentLine
    extend ActiveSupport::Concern

    included do
      attribute :metadata, default: -> { {} }

      belongs_to :order, class_name: 'Spree::Order', optional: true
      belongs_to :cart, class_name: 'Spree::Cart', optional: true

      validates :amount, numericality: true
      validates :label, presence: true
      validate :exactly_one_owner

      extend Spree::DisplayMoney
      money_methods :amount
    end

    # The exactly-one owner of this row — the cart during checkout, the order
    # after completion. New code must read +owner+, never assume +order+.
    #
    # @return [Spree::Cart, Spree::Order, nil]
    def owner
      order || cart
    end

    def amount=(amount)
      self[:amount] = Spree::LocalizedNumber.parse(amount)
    end

    def currency
      owner&.currency
    end

    private

    def exactly_one_owner
      errors.add(:base, Spree.t('errors.messages.exactly_one_of_cart_or_order')) unless [order, cart].compact.one?
    end
  end
end
