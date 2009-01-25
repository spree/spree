# Uncomment this if you reference any of your controllers in activate
require_dependency 'application'

class PaymentGatewayExtension < Spree::Extension
  version "1.0"
  description "Provides basic payment gateway functionality.  User specifies an ActiveMerchant compatible gateway 
  to use in the aplication."

  def activate  
    # Set the global "gateway mode" for active merchant (depending on what environment we're in)
    ActiveMerchant::Billing::Base.gateway_mode = :test unless ENV['RAILS_ENV'] == "production"
    # Mixin the payment_gateway method into the base controller so it can be accessed by the checkout process, etc.
    Creditcard.class_eval do
      # add gateway methods to the creditcard so we can authorize, capture, etc.
      include Spree::PaymentGateway
    end
  end
end