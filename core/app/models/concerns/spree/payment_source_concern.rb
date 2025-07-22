module Spree
  module PaymentSourceConcern
    extend ActiveSupport::Concern

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
  end
end
