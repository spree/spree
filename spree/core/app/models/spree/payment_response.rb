module Spree
  # Lightweight value object for payment gateway responses.
  # Drop-in replacement for ActiveMerchant::Billing::Response.
  class PaymentResponse
    attr_reader :params, :message, :test

    def initialize(success, message, params = {}, options = {})
      @success = success
      @message = message
      @params = params.with_indifferent_access
      @test = options[:test] || false
      @authorization = options[:authorization]
      @avs_result = options[:avs_result] ? { 'code' => options[:avs_result][:code] } : { 'code' => nil }
      @cvv_result = if options[:cvv_result]
                      { 'code' => options[:cvv_result][:code], 'message' => options[:cvv_result][:message] }
                    else
                      { 'code' => nil, 'message' => nil }
                    end
    end

    def success?
      @success
    end

    def test?
      @test
    end

    def authorization
      @authorization
    end

    def avs_result
      @avs_result
    end

    def cvv_result
      @cvv_result
    end
  end
end
