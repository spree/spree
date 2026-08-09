module SpreeStripe
  module PaymentDecorator
    # Stripe reports address/CVC checks as pass/fail/unchecked; Spree stores the
    # equivalent AVS and CVV response codes.
    AVS_CODES = {
      'pass' => { 'pass' => 'Y', 'fail' => 'A', 'unchecked' => 'B' },
      'fail' => { 'pass' => 'Z', 'fail' => 'N' },
      'unchecked' => { 'pass' => 'P', 'unchecked' => 'I' }
    }.freeze unless defined?(AVS_CODES)

    CVV_CODES = { 'pass' => 'M', 'fail' => 'N', 'unchecked' => 'P' }.freeze unless defined?(CVV_CODES)

    def self.prepended(base)
      base.store_accessor :metadata, :stripe_charge_id

      base.before_save :set_cvv_and_avs_response_from_metadata, if: :credit_card_source?
    end

    def set_cvv_and_avs_response_from_metadata
      checks = source.metadata[:checks]
      return if checks.blank?

      self.avs_response ||= AVS_CODES.dig(checks[:address_line1_check], checks[:address_postal_code_check])
      self.cvv_response_code ||= CVV_CODES[checks[:cvc_check]]
    end

    def credit_card_source?
      source.is_a?(Spree::CreditCard)
    end
  end
end

Spree::Payment.prepend(SpreeStripe::PaymentDecorator)
