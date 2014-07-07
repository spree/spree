module Spree
  class ReturnAuthorization < Spree::Base
    belongs_to :order, class_name: 'Spree::Order'

    has_many :return_items, inverse_of: :return_authorization, dependent: :destroy
    has_many :inventory_units, through: :return_items
    has_many :refunds
    belongs_to :stock_location
    before_create :generate_number

    accepts_nested_attributes_for :return_items, allow_destroy: true

    validates :order, presence: true
    validate :must_have_shipped_units, on: :create

    state_machine initial: :authorized do
      after_transition to: :received, do: :process_return
      before_transition to: :refunded, do: :process_refund

      event :receive do
        transition to: :received, from: :authorized, if: :allow_receive?
      end

      event :cancel do
        transition to: :canceled, from: :authorized
      end

      event :refund do
        transition to: :refunded, from: :received
      end

      state all - [:received, :refunded] do
        def updatable?
          true
        end
      end

      state :received, :refunded do
        def updatable?
          false
        end
      end
    end

    def pre_tax_total
      return_items.sum(:pre_tax_amount)
    end

    def additional_tax_total
      return_items.sum(:additional_tax_total)
    end

    def display_pre_tax_total
      Spree::Money.new(pre_tax_total, { currency: currency })
    end

    def currency
      order.nil? ? Spree::Config[:currency] : order.currency
    end

    def returnable_inventory
      order.inventory_units.shipped
    end

    # Used when Adjustment#update! wants to update the related adjustment
    def compute_amount(*args)
      amount.abs * -1
    end

    def total
      pre_tax_total + additional_tax_total
    end

    def amount_due
      total - refunds.sum(:amount)
    end

    def process_refund
      # For now type and order of retrieved payments are not specified
      order.payments.completed.each do |payment|
        break if amount_due <= 0
        credit_allowed = [payment.credit_allowed, amount_due].min
        payment.credit!(credit_allowed, self)
      end

      case amount_due
      when 0
        return true
      when ->(x) { x < 0 }
        errors.add(:base, :amount_due_less_than_zero) and return false
      when ->(x) { x > 0 }
        errors.add(:base, :amount_due_greater_than_zero) and return false
      end
    end

    def refundable_amount
      order.pre_tax_item_amount + order.promo_total
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

      def process_return
        return_items.includes(:inventory_unit).each(&:receive!)

        order.return if inventory_units.all?(&:returned?)
      end

      def allow_receive?
        !inventory_units.empty?
      end
  end
end
