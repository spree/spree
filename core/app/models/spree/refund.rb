module Spree
  class Refund < Spree::Base
    belongs_to :payment, inverse_of: :refunds
    belongs_to :return_authorization # optional

    has_many :log_entries, as: :source

    validates :payment, presence: true
    validates :transaction_id, presence: true
    validates :amount, presence: true, numericality: {greater_than: 0}

    # attempts to perform the refund
    # if successful it returns the refund, otherwise it raises
    def self.perform!(payment, amount, return_authorization=nil)
      check_amount(amount)
      check_environment(payment)

      credit_cents = Spree::Money.new(amount.to_f, currency: payment.currency).money.cents

      response = process!(payment, credit_cents)

      refund = create!({
        payment: payment,
        return_authorization: return_authorization,
        transaction_id: response.authorization,
        amount: amount,
      })

      refund.log_entries.create!(details: response.to_yaml)

      refund
    end

    # return an activemerchant response object if successful or else raise an error
    def self.process!(payment, credit_cents)
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
    def self.check_environment(payment)
      return if payment.payment_method.environment == Rails.env
      message = Spree.t(:gateway_config_unavailable) + " - #{Rails.env}"
      raise Core::GatewayError.new(message)
    end

    def self.check_amount(amount)
      unless amount > 0
        raise Core::GatewayError.new(Spree.t(:refund_amount_must_be_greater_than_zero))
      end
    end

    def money
      Spree::Money.new(amount, { currency: payment.currency })
    end
    alias display_amount money

  end
end
