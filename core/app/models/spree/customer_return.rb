module Spree
  class CustomerReturn < Spree::Base
    belongs_to :stock_location

    has_many :reimbursements, inverse_of: :customer_return
    has_many :return_authorizations, through: :return_items
    has_many :return_items, inverse_of: :customer_return

    after_create :process_return!
    before_create :generate_number

    validates :return_items, presence: true
    validates :stock_location, presence: true

    validate :must_have_return_authorization, on: :create
    validate :return_items_belong_to_same_order

    accepts_nested_attributes_for :return_items

    extend DisplayMoney
    money_methods pre_tax_total: { currency: Spree::Config[:currency] }

    def completely_decided?
      !return_items.undecided.exists?
    end

    def fully_reimbursed?
      completely_decided? && return_items.accepted.includes(:reimbursement).all? { |return_item| return_item.reimbursement.try(:reimbursed?) }
    end

    # Temporarily tie a customer_return to one order
    def order
      return nil if return_items.blank?
      return_items.first.inventory_unit.order
    end

    def order_id
      order.try(:id)
    end

    def pre_tax_total
      return_items.sum(:pre_tax_amount)
    end

    private

    def inventory_units
      return_items.flat_map(&:inventory_unit)
    end

    def must_have_return_authorization
      if item = return_items.find { |ri| ri.return_authorization.blank? }
        errors.add(:base, Spree.t(:missing_return_authorization, item_name: item.inventory_unit.variant.name))
      end
    end

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
      if return_items.select { |return_item| return_item.inventory_unit.order_id != order_id }.any?
        errors.add(:base, Spree.t(:return_items_cannot_be_associated_with_multiple_orders))
      end
    end
  end
end
