module Spree
  class ReturnAuthorization < Spree::Base
    include Spree::Core::NumberGenerator.new(prefix: 'RA', length: 9)

    belongs_to :order, class_name: 'Spree::Order', inverse_of: :return_authorizations

    has_many :return_items, inverse_of: :return_authorization, dependent: :destroy
    with_options through: :return_items do
      has_many :inventory_units
      has_many :customer_returns
    end

    belongs_to :stock_location
    belongs_to :reason, class_name: 'Spree::ReturnAuthorizationReason', foreign_key: :return_authorization_reason_id

    after_save :generate_expedited_exchange_reimbursements

    accepts_nested_attributes_for :return_items, allow_destroy: true

    validates :number, uniqueness: true
    validates :order, :reason, :stock_location, presence: true
    validate :must_have_shipped_units, on: :create

    # These are called prior to generating expedited exchanges shipments.
    # Should respond to a "call" method that takes the list of return items
    class_attribute :pre_expedited_exchange_hooks
    self.pre_expedited_exchange_hooks = []

    state_machine initial: :authorized do
      before_transition to: :canceled, do: :cancel_return_items

      event :cancel do
        transition to: :canceled, from: :authorized, if: ->(return_authorization) { return_authorization.can_cancel_return_items? }
      end
    end

    extend DisplayMoney
    money_methods :pre_tax_total

    self.whitelisted_ransackable_attributes = ['memo', 'number', 'state']

    def pre_tax_total
      return_items.sum(:pre_tax_amount)
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

    def can_cancel_return_items?
      return_items.any?(&:can_cancel?) || return_items.blank?
    end

    private

    def must_have_shipped_units
      if order.nil? || order.inventory_units.shipped.none?
        errors.add(:order, Spree.t(:has_no_shipped_units))
      end
    end

    def cancel_return_items
      return_items.each { |item| item.cancel! if item.can_cancel? }
    end

    def generate_expedited_exchange_reimbursements
      return unless Spree::Config[:expedited_exchanges]

      items_to_exchange = return_items.select(&:exchange_required?)
      items_to_exchange.each(&:attempt_accept)
      items_to_exchange.select!(&:accepted?)

      return if items_to_exchange.blank?

      pre_expedited_exchange_hooks.each { |h| h.call items_to_exchange }

      reimbursement = Reimbursement.new(return_items: items_to_exchange, order: order)

      if reimbursement.save
        reimbursement.perform!
      else
        errors.add(:base, reimbursement.errors.full_messages)
        raise ActiveRecord::RecordInvalid, self
      end
    end
  end
end
