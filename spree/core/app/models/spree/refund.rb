module Spree
  class Refund < Spree.base_class
    has_prefix_id :re  # Stripe: re_

    include Spree::Metafields
    include Spree::Metadata
    if defined?(Spree::Security::Refunds)
      include Spree::Security::Refunds
    end

    publishes_lifecycle_events

    with_options inverse_of: :refunds do
      belongs_to :payment
      belongs_to :reimbursement, optional: true
    end
    belongs_to :reason, class_name: 'Spree::RefundReason', foreign_key: :refund_reason_id
    belongs_to :refunder, class_name: Spree.admin_user_class.to_s, optional: true

    has_many :log_entries, as: :source

    with_options presence: true do
      validates :payment, :reason
      # can't require this on create because the perform! in after_create needs to run first
      validates :transaction_id, on: :update
      validates :amount, numericality: { greater_than: 0, allow_nil: true }
    end
    validate :amount_is_less_than_or_equal_to_allowed_amount, on: :create, if: :amount

    after_create :perform!
    after_create :create_log_entry

    scope :non_reimbursement, -> { where(reimbursement_id: nil) }

    attr_reader :response

    delegate :order, :currency, to: :payment

    def money
      Spree::Money.new(amount, currency: currency)
    end
    alias display_amount money

    class << self
      def total_amount_reimbursed_for(reimbursement)
        reimbursement.refunds.to_a.sum(&:amount)
      end
    end

    def description
      payment.payment_method.name
    end

    # return items for the refund
    #
    # @return [Array<Spree::ReturnItem>]
    def return_items
      return [] unless reimbursement.present?

      reimbursement.customer_return&.return_items || reimbursement.return_items
    end

    # Returns true if the refund is editable.
    #
    # @return [Boolean]
    def editable?
      !payment.order.canceled?
    end

    private

    # attempts to perform the refund.
    # raises an error if the refund fails.
    def perform!
      return true if transaction_id.present?

      credit_cents = Spree::Money.new(amount.to_f, currency: currency).amount_in_cents

      @response = process!(credit_cents)

      self.transaction_id = @response.authorization
      update_columns(transaction_id: transaction_id)
      update_order
    end

    # return a payment response object if successful or else raise an error
    def process!(credit_cents)
      refund_total_in_cents = calculate_refund_amount(credit_cents)

      response = if payment.payment_method.payment_profiles_supported?
                   payment.payment_method.credit(refund_total_in_cents, payment.source, payment.transaction_id, originator: self)
                 else
                   payment.payment_method.credit(refund_total_in_cents, payment.transaction_id, originator: self)
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

    def create_log_entry
      log_entries.create!(details: @response.to_yaml)
    end

    def amount_is_less_than_or_equal_to_allowed_amount
      if amount > payment.credit_allowed
        errors.add(:amount, :greater_than_allowed)
      end
    end

    def update_order
      payment.order.updater.update
    end
  end
end
