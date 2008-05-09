module Spree
  module PaymentGateway
    # Instantiates the selected PAYMENT_GATEWAY and initializes with GATEWAY_OPTIONS (configured in environment.rb)
    def payment_gateway
      return Spree::BogusGateway.new if ENV['RAILS_ENV'] == "development"
      # Temporarily use the bogus gateway (even in production) until we implement the admin screens to configure this.
      Spree::BogusGateway.new
      #PAYMENT_GATEWAY.constantize.new(GATEWAY_OPTIONS)
    end  
  end
end