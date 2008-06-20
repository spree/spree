module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Base
      # Set ActiveMerchant gateways in test mode.
      #
      #   ActiveMerchant::Billing::Base.gateway_mode = :test
      mattr_accessor :gateway_mode
      
      # Set ActiveMerchant gateways in test mode.
      #
      #   ActiveMerchant::Billing::Base.gateway_mode = :test
      mattr_accessor :integration_mode
      
      # Set both the mode of both the gateways and integrations
      # at once
      mattr_reader :mode

      def self.mode=(mode)
        @@mode = mode
        self.gateway_mode = mode
        self.integration_mode = mode
      end

      self.mode = :production
                                                                
      # Return the matching gateway for the provider
      # * <tt>bogus</tt>: BogusGateway - Does nothing (for testing)
      # * <tt>moneris</tt>: MonerisGateway
      # * <tt>authorize_net</tt>: AuthorizeNetGateway
      # * <tt>trust_commerce</tt>: TrustCommerceGateway
      # 
      #   ActiveMerchant::Billing::Base.gateway('moneris').new
      def self.gateway(name)
        Billing.const_get("#{name.to_s.downcase}_gateway".camelize)
      end
      

      # Return the matching integration module
      # You can then get the notification from the module
      # * <tt>bogus</tt>: Bogus - Does nothing (for testing)      
      # * <tt>chronopay</tt>: Chronopay - Does nothing (for testing)
      # * <tt>paypal</tt>: Chronopay - Does nothing (for testing)
      #   
      #   chronopay = ActiveMerchant::Billing::Base.integration('chronopay')
      #   notification = chronopay.notification(raw_post)
      #
      def self.integration(name)
        Billing::Integrations.const_get("#{name.to_s.downcase}".camelize)
      end
      
      # A check to see if we're in test mode
      def self.test?
        self.gateway_mode == :test
      end
    end             
  end
end
