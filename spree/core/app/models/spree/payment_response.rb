module Spree
  # Lightweight value object representing a payment gateway response.
  #
  # This is Spree's native replacement for +ActiveMerchant::Billing::Response+.
  # It carries the same interface so existing payment method implementations
  # (Bogus, Check, StoreCredit, and third-party gateways) can return it without
  # any callers needing to change.
  #
  # @example Successful authorization
  #   Spree::PaymentResponse.new(true, 'Transaction approved', {},
  #     authorization: 'ch_abc123',
  #     avs_result:    { code: 'D' },
  #     cvv_result:    { code: 'M', message: 'Match' },
  #     test:          true)
  #
  # @example Failed charge
  #   Spree::PaymentResponse.new(false, 'Card declined', { message: 'Insufficient funds' })
  #
  class PaymentResponse
    # @return [HashWithIndifferentAccess] raw gateway params
    attr_reader :params

    # @return [String] human-readable result message
    attr_reader :message

    # @return [Boolean] whether the response came from a test/sandbox environment
    attr_reader :test

    # @return [String, nil] gateway authorization / transaction reference
    attr_reader :authorization

    # @return [Hash] AVS (Address Verification System) result with +"code"+ key
    attr_reader :avs_result

    # @return [Hash] CVV result with +"code"+ and +"message"+ keys
    attr_reader :cvv_result

    # @return [String, nil] the provider's id for a capture it accepted but has
    #   not answered yet; a capture's authorization becomes the payment's
    #   response_code, so it cannot travel there
    attr_reader :reference

    # @param success [Boolean] whether the gateway action succeeded
    # @param message [String]  human-readable result message
    # @param params  [Hash]    raw key/value pairs returned by the gateway
    # @param options [Hash]    additional metadata
    # @option options [String]  :authorization  gateway transaction reference
    # @option options [Hash]    :avs_result     must contain +:code+
    # @option options [Hash]    :cvv_result     may contain +:code+ and +:message+
    # @option options [Boolean] :test           sandbox/test flag
    # @option options [Boolean] :requested      the provider accepted the request and
    #   reports its outcome later, by webhook
    # @option options [String]  :reference      the provider's id for a requested capture
    def initialize(success, message, params = {}, options = {})
      @success = success
      @message = message
      @params = params.with_indifferent_access
      @test = options[:test] || false
      @authorization = options[:authorization]
      @requested = options[:requested] || false
      @reference = options[:reference]
      @avs_result = options[:avs_result] ? { 'code' => options[:avs_result][:code] } : { 'code' => nil }
      @cvv_result = if options[:cvv_result]
                      { 'code' => options[:cvv_result][:code], 'message' => options[:cvv_result][:message] }
                    else
                      { 'code' => nil, 'message' => nil }
                    end
    end

    # @return [Boolean] whether the gateway action succeeded
    def success?
      @success
    end

    # Whether the provider accepted the request and will report its outcome by
    # webhook. Only a gateway that returns that outcome from
    # +parse_webhook_event+ may answer this.
    #
    # @return [Boolean]
    def requested?
      @requested
    end

    # @return [Boolean] whether the response came from a test/sandbox environment
    def test?
      @test
    end
  end
end
