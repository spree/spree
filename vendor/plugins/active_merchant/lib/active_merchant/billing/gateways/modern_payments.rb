require File.dirname(__FILE__) + '/modern_payments_cim'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class ModernPaymentsGateway < Gateway
      self.supported_countries = ModernPaymentsCimGateway.supported_countries
      self.supported_cardtypes = ModernPaymentsCimGateway.supported_cardtypes
      self.homepage_url = ModernPaymentsCimGateway.homepage_url
      self.display_name = ModernPaymentsCimGateway.display_name
      
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end
      
      def purchase(money, credit_card, options = {})
        customer_response = cim.create_customer(options)
        return customer_response unless customer_response.success?
        
        customer_id = customer_response.params["create_customer_result"]
        
        card_response = cim.modify_customer_credit_card(customer_id, credit_card)
        return card_response unless card_response.success?
        
        cim.authorize_credit_card_payment(customer_id, money)
      end
      
      private
      def cim
        @cim ||= ModernPaymentsCimGateway.new(@options)
      end
    end
  end
end

