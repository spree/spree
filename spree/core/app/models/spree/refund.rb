module Spree
  class Refund < Spree.base_class
    has_prefix_id :re  # Stripe: re_

    include Spree::HasCustomFields
    include Spree::Metadata
    include Spree::InstrumentsGatewayCalls
    if defined?(Spree::Security::Refunds)
      include Spree::Security::Refunds
    end

    publishes_lifecycle_events

    belongs_to :payment, inverse_of: :refunds
    # Which order is being put right. A refund against an ordinary payment
    # takes the payment's order automatically; one against a payment shared by
    # a split checkout must name the child order it applies to, since the
    # payment covers several and only one of them is being refunded.
    belongs_to :order, class_name: 'Spree::Order', optional: true, inverse_of: :refunds
    belongs_to :reason, class_name: 'Spree::RefundReason', foreign_key: :refund_reason_id
    belongs_to :refunder, class_name: Spree.admin_user_class.to_s, optional: true
    # What triggered this refund — a Spree::Return today, later an Exchange
    # or Claim; nil for a manual refund. Deliberately polymorphic: the set is
    # small and closed, and refunds are never bulk-queried in a hot path.
    belongs_to :originator, polymorphic: true, optional: true

    with_options presence: true do
      # not required on create — perform! sets it after the gateway credit
      validates :transaction_id, on: :update
      validates :amount, numericality: { greater_than: 0, allow_nil: true }
    end
    validate :amount_is_less_than_or_equal_to_allowed_amount, on: :create, if: :amount
    validate :order_is_covered_by_payment, on: :create

    attr_reader :response

    delegate :currency, to: :payment

    # A refund always knows its order, so every reader — the scopes, the
    # ledger, the split's share — can rely on the column rather than walking
    # back through a payment that may belong to several orders.
    before_validation :assign_order_from_payment, on: :create

    def amount=(amount)
      self[:amount] = Spree::LocalizedNumber.parse(amount)
    end

    def money
      Spree::Money.new(amount, currency: currency)
    end
    alias display_amount money

    def description
      payment.payment_method.name
    end

    # The lines this refund paid for, when it came from a return.
    #
    # @return [Array<Spree::ReturnLineItem>]
    def return_line_items
      return [] unless originator.is_a?(Spree::Return)

      originator.return_line_items.to_a
    end

    # Returns true if the refund is editable.
    #
    # Read through the refund's own order: a payment shared by a split checkout
    # belongs to no single order, so asking the payment would answer nil.
    #
    # @return [Boolean]
    def editable?
      order.present? && !order.canceled?
    end

    # Credits the refund back at the gateway — the money movement, called
    # explicitly from a workflow's external_step, never from a callback. A
    # blank transaction_id means the credit has not happened yet; a present
    # one makes this a no-op, so replays are safe.
    #
    # @raise [Spree::Core::GatewayError] when the gateway declines or is down
    # @return [true]
    def perform!
      return true if transaction_id.present?

      credit_cents = Spree::Money.new(amount.to_f, currency: currency).amount_in_cents

      @response = process!(credit_cents)

      self.transaction_id = @response.authorization
      update_columns(transaction_id: transaction_id)
      update_order
      true
    end

    private

    # A payment belonging to one order answers this for itself; a payment
    # shared by a split checkout cannot, so the caller has to have said which
    # order it is refunding.
    def assign_order_from_payment
      self.order_id ||= payment&.order_id
    end

    # A refund may only put right an order the payment actually paid for.
    # Without this a caller can name any order: the gateway credits this
    # payment while the totals of an unrelated one are recomputed, and on a
    # shared payment the share that should have recorded the refund is never
    # found.
    def order_is_covered_by_payment
      return if payment.blank?

      # A shared payment cannot say which of its orders is being put right, so
      # the caller has to — and nothing can fill it in afterwards. Left blank,
      # the gateway would be credited while no child's totals or share moved.
      if order_id.blank?
        errors.add(:order, :blank) if payment.grouped?
        return
      end

      covered = if payment.grouped?
                  payment.payment_splits.exists?(order_id: order_id)
                else
                  payment.order_id == order_id
                end

      errors.add(:order, :invalid) unless covered
    end

    # return a payment response object if successful or else raise an error
    def process!(credit_cents)
      refund_total_in_cents = calculate_refund_amount(credit_cents)

      response = instrument_gateway_call(:credit, payment.payment_method) do
        if payment.payment_method.payment_profiles_supported?
          payment.payment_method.credit(refund_total_in_cents, payment.source, payment.transaction_id, originator: self)
        else
          payment.payment_method.credit(refund_total_in_cents, payment.transaction_id, originator: self)
        end
      end

      if response.success?
        track_order_as_refunded(refund_total_in_cents)
      else
        Rails.logger.error(Spree.t(:gateway_error) + "  #{response.to_yaml}")
        text = response.params['message'] || response.params['response_reason_text'] || response.message
        raise Core::GatewayError, text
      end

      response
    rescue Spree::PaymentConnectionError => e
      Rails.logger.error(Spree.t(:gateway_error) + "  #{e.inspect}")
      raise Core::GatewayError, Spree.t(:unable_to_connect_to_gateway)
    end

    def calculate_refund_amount(credit_cents)
      # Overwrite this for more complex calculations
      credit_cents
    end

    def track_order_as_refunded(credit_cents)
      # You can track refunds here
    end

    def amount_is_less_than_or_equal_to_allowed_amount
      if amount > payment.credit_allowed
        errors.add(:amount, :greater_than_allowed)
      end
    end

    # Re-sums the order this refund put right. Read through the refund's own
    # order rather than the payment's: a payment shared by a split checkout
    # belongs to no single order, and it is this one order's money that moved.
    def update_order
      order&.recalculate_totals!
    end
  end
end
