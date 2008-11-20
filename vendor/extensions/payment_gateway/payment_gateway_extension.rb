# Uncomment this if you reference any of your controllers in activate
require_dependency 'application'
require 'active_merchant'

class PaymentGatewayExtension < Spree::Extension
  version "1.0"
  description "Provides basic payment gateway functionality.  User specifies an ActiveMerchant compatible gateway 
  to use in the aplication."

  def activate  
    # Set the global "gateway mode" for active merchant (depending on whate environment we're in)
    ActiveMerchant::Billing::Base.gateway_mode = :test unless ENV['RAILS_ENV'] == "production"
    # Mixin the payment_gateway method into the base controller so it can be accessed by the checkout process, etc.
    CreditcardPayment.class_eval do
      before_save :authorize
      include Spree::PaymentGateway
    end
    Order.class_eval do 
      Order.state_machines['state'].after_transition(:to => 'captured', :do => lambda {|order| order.creditcard_payment.capture})
      Order.state_machines['state'].after_transition(:to => 'canceled', :do => lambda {|order| order.creditcard_payment.void})
      Order.state_machines['state'].after_transition(:to => 'returned', :do => lambda {|order| order.creditcard_payment.void})
    end
  end
end