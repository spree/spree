module Spree
  class Refund < Spree::Base
    belongs_to :payment, inverse_of: :refunds
    belongs_to :reason, class_name: 'Spree::RefundReason', foreign_key: :refund_reason_id
    belongs_to :reimbursement, inverse_of: :refunds

    has_many :log_entries, as: :source

    validates :payment, presence: true
    validates :reason, presence: true
    validates :transaction_id, presence: true, on: :update # can't require this on create because the before_create needs to run first
    validates :amount, presence: true, numericality: {greater_than: 0}

    validate :amount_is_less_than_or_equal_to_allowed_amount, on: :create

    after_create :perform!
    after_create :create_log_entry

    scope :non_reimbursement, -> { where(reimbursement_id: nil) }

    def money
      Spree::Money.new(amount, { currency: payment.currency })
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

    private

    # attempts to perform the refund.
    # raises an error if the refund fails.
    def perform!
      return true if transaction_id.present?

      credit_cents = Spree::Money.new(amount.to_f, currency: payment.currency).money.cents

      @response = process!(credit_cents)

      self.transaction_id = @response.authorization
      update_columns(transaction_id: transaction_id)
      update_order
    end

    # return an activemerchant response object if successful or else raise an error
    def process!(credit_cents)
      response = if payment.payment_method.payment_profiles_supported?
        payment.payment_method.credit(credit_cents, payment.source, payment.transaction_id, {originator: self})
      else
        payment.payment_method.credit(credit_cents, payment.transaction_id, {originator: self})
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
