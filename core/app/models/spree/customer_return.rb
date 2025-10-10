module Spree
  class CustomerReturn < Spree.base_class
    include Spree::Core::NumberGenerator.new(prefix: 'CR', length: 9)
    include Spree::NumberIdentifier
    include Spree::Metafields
    include Spree::Metadata
    if defined?(Spree::Webhooks::HasWebhooks)
      include Spree::Webhooks::HasWebhooks
    end

    belongs_to :stock_location
    belongs_to :store, class_name: 'Spree::Store', inverse_of: :customer_returns

    has_many :reimbursements, inverse_of: :customer_return
    has_many :return_items, inverse_of: :customer_return
    has_many :return_authorizations, through: :return_items

    after_create :process_return!

    validates :store, presence: true
    validates :return_items, :stock_location, presence: true
    validate :must_have_return_authorization, on: :create
    validate :return_items_belong_to_same_order

    accepts_nested_attributes_for :return_items

    extend DisplayMoney
    money_methods :pre_tax_total

    self.whitelisted_ransackable_attributes = ['number']

    delegate :id, to: :order, prefix: true, allow_nil: true

    def completely_decided?
      !return_items.undecided.exists?
    end

    def fully_reimbursed?
      completely_decided? && return_items.accepted.includes(:reimbursement).all? { |return_item| return_item.reimbursement.try(:reimbursed?) }
    end

    def currency
      order&.currency
    end

    # Temporarily tie a customer_return to one order
    def order
      return nil if return_items.blank?
      return nil if return_items.first.inventory_unit.blank?

      return_items.first.inventory_unit.order
    end

    def pre_tax_total
      return_items.sum(:pre_tax_amount)
    end

    def can_create_reimbursement?
      !fully_reimbursed? && completely_decided? && no_pending_reimbursements?
    end

    def no_pending_reimbursements?
      if association(:reimbursements).loaded?
        reimbursements.select(&:pending?).empty?
      else
        reimbursements.where(reimbursement_status: :pending).none?
      end
    end

    private

    def inventory_units
      return_items.flat_map(&:inventory_unit)
    end

    def must_have_return_authorization
      if (item = return_items.find { |ri| ri.return_authorization.blank? })
        errors.add(:base, Spree.t(:missing_return_authorization, item_name: item.inventory_unit.variant.name))
      end
    end

    def process_return!
      return_items.each(&:receive!)
      order.return! if order.all_inventory_units_returned?
    end

    def return_items_belong_to_same_order
      if return_items.any? { |return_item| return_item.inventory_unit.order_id != order_id }
        errors.add(:base, Spree.t(:return_items_cannot_be_associated_with_multiple_orders))
      end
    end
  end
end
