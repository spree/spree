module Spree
  class CustomerReturn < Spree::Base
    class_attribute :return_item_tax_calculator
    self.return_item_tax_calculator = ReturnItemTaxCalculator

    belongs_to :stock_location

    has_many :refunds, inverse_of: :customer_return
    has_many :return_items, inverse_of: :customer_return
    has_many :return_authorizations, through: :return_items

    after_create :process_return!
    before_create :generate_number

    validates :return_items, presence: true
    validates :stock_location, presence: true
    validate :return_items_belong_to_same_order

    accepts_nested_attributes_for :return_items

    def pre_tax_total
      return_items.sum(:pre_tax_amount)
    end

    def display_pre_tax_total
      Spree::Money.new(pre_tax_total, { currency: Spree::Config[:currency] })
    end

    # Temporarily tie a customer_return to one order
    def order
      return nil if return_items.blank?
      return_items.first.inventory_unit.order
    end

    def order_id
      order.try(:id)
    end

    #
    # Refunds
    #

    def refund
      return_item_tax_calculator.call return_items.includes(inventory_unit: {line_item: :order}).to_a

      # For now type and order of retrieved payments are not specified
      order.payments.completed.each do |payment|
        break unless amount_due > 0
        credit_allowed = [payment.credit_allowed, amount_due].min
        payment.refunds.create!({
          customer_return: self,
          amount: credit_allowed,
          reason: Spree::RefundReason.return_processing_reason,
        })
      end

      errors.add(:base, Spree.t("validation.amount_due_less_than_zero")) if amount_due < 0
      errors.add(:base, Spree.t("validation.amount_due_greater_than_zero")) if amount_due > 0
      errors.blank?
    end

    def pre_tax_total
      return_items.sum(:pre_tax_amount)
    end

    def additional_tax_total
      return_items.sum(:additional_tax_total)
    end

    def total
      pre_tax_total + additional_tax_total
    end

    def refund_total
      refunds.sum(:amount)
    end

    def display_refund_total
      Spree::Money.new(refund_total, { currency: Spree::Config[:currency] })
    end

    def amount_due
      # rounds down to avoid edge cases where we might try to refund more than is available
      (total - refunds.sum(:amount)).round(2, :down)
    end

    def refunded?
      amount_due.zero?
    end

    private

    def generate_number
      self.number ||= loop do
        random = "CR#{Array.new(9){rand(9)}.join}"
        break random unless self.class.exists?(number: random)
      end
    end

    def process_return!
      return_items.each(&:receive!)
      order.return! if order.all_inventory_units_returned?
    end

    def return_items_belong_to_same_order
      if return_items.select{ |return_item| return_item.inventory_unit.order_id != order_id }.any?
        errors.add(:base, Spree.t(:return_items_cannot_be_associated_with_multiple_orders))
      end
    end

    def inventory_units
      return_items.flat_map(&:inventory_unit)
    end

  end
end

