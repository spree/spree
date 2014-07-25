module Spree
  class Refund < Spree::Base
    belongs_to :payment, inverse_of: :refunds
    belongs_to :customer_return # optional
    belongs_to :reason, class_name: 'Spree::RefundReason', foreign_key: :refund_reason_id

    has_many :log_entries, as: :source

    validates :payment, presence: true
    validates :reason, presence: true
    validates :transaction_id, presence: true, on: :update # can't require this on create because the before_create needs to run first
    validates :amount, presence: true, numericality: {greater_than: 0}

    validate :check_payment_environment, on: :create, if: :payment
    validate :amount_is_less_than_or_equal_to_allowed_amount, on: :create

    before_create :perform!
    after_create :create_log_entry

    def money
      Spree::Money.new(amount, { currency: payment.currency })
    end
    alias display_amount money

    private

    # attempts to perform the refund.
    # raises an error if the refund fails.
    def perform!
      credit_cents = Spree::Money.new(amount.to_f, currency: payment.currency).money.cents

      @response = process!(credit_cents)

      self.transaction_id = @response.authorization
    end

    # return an activemerchant response object if successful or else raise an error
    def process!(credit_cents)
      response = if payment.payment_method.payment_profiles_supported?
        payment.payment_method.credit(credit_cents, payment.source, payment.transaction_id, {})
      else
        payment.payment_method.credit(credit_cents, payment.transaction_id, {})
      end

      if !response.success?
        logger.error(Spree.t(:gateway_error) + "  #{response.to_yaml}")
        text = response.params['message'] || response.params['response_reason_text'] || response.message
        raise Core::GatewayError.new(text)
      end

      response
    rescue ActiveMerchant::ConnectionError => e
      logger.error(Spree.t(:gateway_error) + "  #{e.inspect}")
      raise Core::GatewayError.new(Spree.t(:unable_to_connect_to_gateway))
    end

    # Saftey check to make sure we're not accidentally performing operations on a live gateway.
    # Ex. When testing in staging environment with a copy of production data.
    def check_payment_environment
      if payment.payment_method.environment != Rails.env
        message = Spree.t(:gateway_config_unavailable) + " - #{Rails.env}"
        errors.add(:base, message)
      end
    end

    def create_log_entry
      log_entries.create!(details: @response.to_yaml)
    end

    def amount_is_less_than_or_equal_to_allowed_amount
      if amount > payment.credit_allowed
        errors.add(:amount, :greater_than_allowed)
      end
    end
  end
end
