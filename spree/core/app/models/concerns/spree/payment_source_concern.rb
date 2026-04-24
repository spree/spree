module Spree
  module PaymentSourceConcern
    extend ActiveSupport::Concern

    included do
      before_destroy :cleanup_payments_on_incomplete_orders
    end

    # Available actions for the payment source.
    # @return [Array<String>]
    def actions
      %w{capture void credit}
    end

    # Indicates whether its possible to capture the payment
    # @param payment [Spree::Payment]
    # @return [Boolean]
    def can_capture?(payment)
      payment.pending? || payment.checkout?
    end

    # Indicates whether its possible to void the payment.
    # @param payment [Spree::Payment]
    # @return [Boolean]
    def can_void?(payment)
      !payment.failed? && !payment.void?
    end

    # Indicates whether its possible to credit the payment.  Note that most gateways require that the
    # payment be settled first which generally happens within 12-24 hours of the transaction.
    # @param payment [Spree::Payment]
    # @return [Boolean]
    def can_credit?(payment)
      payment.completed? && payment.credit_allowed > 0
    end

    # Returns true if the payment source has a payment profile.
    # @return [Boolean]
    def has_payment_profile?
      gateway_customer_profile_id.present? || gateway_payment_profile_id.present?
    end

    private

    # Cleans up payments on incomplete orders before the source is destroyed.
    # Invalidates checkout-state payments and voids non-checkout payments.
    def cleanup_payments_on_incomplete_orders
      incomplete_payments = Spree::Payment.valid
                                          .where(source: self)
                                          .joins(:order)
                                          .merge(Spree::Order.incomplete)

      incomplete_payments.checkout.each(&:invalidate!)
      incomplete_payments.where.not(state: :checkout).each(&:void!)
    end
  end
end
