module Spree
  class ReturnAuthorization < Spree::Base
    belongs_to :order, class_name: 'Spree::Order'

    has_many :return_items, inverse_of: :return_authorization, dependent: :destroy
    has_many :inventory_units, through: :return_items
    has_many :customer_returns, through: :return_items

    belongs_to :stock_location
    belongs_to :reason, class_name: 'Spree::ReturnAuthorizationReason', foreign_key: :return_authorization_reason_id
    before_create :generate_number

    accepts_nested_attributes_for :return_items, allow_destroy: true

    validates :order, presence: true
    validates :reason, presence: true
    validates :stock_location, presence: true
    validate :must_have_shipped_units, on: :create

    state_machine initial: :authorized do
      before_transition to: :canceled, do: :cancel_return_items

      event :cancel do
        transition to: :canceled, from: :authorized
      end

    end

    def pre_tax_total
      return_items.sum(:pre_tax_amount)
    end

    def display_pre_tax_total
      Spree::Money.new(pre_tax_total, { currency: currency })
    end

    def currency
      order.nil? ? Spree::Config[:currency] : order.currency
    end

    def refundable_amount
      order.pre_tax_item_amount + order.promo_total
    end

    def customer_returned_items?
      customer_returns.exists?
    end

    private

      def must_have_shipped_units
        if order.nil? || order.inventory_units.shipped.none?
          errors.add(:order, Spree.t(:has_no_shipped_units))
        end
      end

      def generate_number
        self.number ||= loop do
          random = "RA#{Array.new(9){rand(9)}.join}"
          break random unless self.class.exists?(number: random)
        end
      end

      def cancel_return_items
        return_items.each(&:cancel!)
      end

  end
end
